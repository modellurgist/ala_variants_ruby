module Screens
  # Checking out a cart: an address, then payment, which runs as a job, then settling the order. Built
  # per request and once more inside the job (`charge` is the input the job calls). The flow, its
  # URLs and its words are this screen's; the payment instances carry the store's choices. The steps,
  # the paying, the charge and the settling are placed only here, so the page calls them and uses what
  # they answer; the lines, pricing and totals, placed by the cart too, stay wired.
  class Checkout
    include ProgrammingParadigms::Wiring
    include DomainAbstractions
    include Rules

    FLOW = [ [ :address, :submit_address, :payment ], [ :payment, :edit_address, :address ],
             [ :payment, :pay, :processing ], [ :error, :pay, :processing ],
             [ :processing, :succeeded, :complete ], [ :processing, :failed, :error ] ].freeze
    URL_EDGES = [ [ :payment, :address ] ].freeze
    MILESTONES = [ [ :address, "Address" ], [ :payment, "Payment" ] ].freeze
    STEP_ORDER = %i[address payment processing error complete].freeze
    # the page's body per step; complete never renders, it leaves for the success page
    STEP_VIEWS = { address: "checkouts/address", payment: "checkouts/payment", processing: "checkouts/processing", error: "checkouts/error" }.freeze
    BLOCKED = { empty: "Your cart is empty", out_of_stock: "Some items are out of stock" }.freeze
    ADDRESS_FIELDS = [ [ :name, :text, "Full name" ], [ :line1, :text, "Address" ], [ :city, :text, "City" ], [ :postal_code, :text, "Postal code" ] ].freeze
    STATUS_TARGET = "checkout_status"
    OUTCOMES = %i[complete error].freeze
    TEXTS = { back: "← Back to cart", heading: "Checkout", continue: "Continue to payment", edit_address: "Edit address", pay: "Pay",
              payment_failed: "Payment failed.", try_again: "Try again", processing: "Processing payment…", redirecting: "Redirecting…",
              total: Store::SUMMARY_TEXTS[:total] }.freeze
    # the checkout reads the lines and never changes them
    GROUNDED = %i[lines.changed lines.adding lines.rows lines.row_added lines.row_changed lines.row_removed lines.removed lines.saved lines.line
                  items.added pricing.promo_applied pricing.promo_rejected].freeze

    attr_reader :config, :summary, :flash, :feed, :patches

    def parts = { lines: @lines, pricing: @pricing, totals: @totals, items: @items,
                  feed: @feed, publish_stock: @publish_stock, publish_paid: @publish_paid, publish_declined: @publish_declined }

    def step = @steps.step
    def form = @steps.record

    # the lines are a value: every input that asks them loads them first
    def start
      load_lines
      blocked = @flow.start(@lines.lines)
      @flash[:alert] = BLOCKED[blocked] if blocked
    end

    def show(requested) = (load_lines; run(:pricing, @pricing.load); @steps.show(requested))
    def validate(params) = @steps.validate(params, :address)
    def submit_address(params) = @steps.submit(params, context: :address, event: :submit_address)
    def edit_address = @steps.advance(:edit_address)

    def pay
      load_lines
      case @flow.pay(@lines.lines)
      in { blocked: } then @flash[:alert] = BLOCKED[blocked]
      in { payment: } then ProgrammingParadigms::PushLater.push(self, :charge, payment)
      end
    end

    # the job's input: settle and record a payment, or record its decline, and tell the waiting page
    def charge(payment)
      case @charge.charge(payment)
      in [ :charged, reference ]
        @settle.settle(reference).each { run(:publish_stock, @publish_stock.push(_1)) }
        @flow.succeeded(reference)
        run(:publish_paid, @publish_paid.push(reference))
      in [ :declined, reason ]
        @flow.failed(reason)
        run(:publish_declined, @publish_declined.push(reason))
      end
    end

    def live(message) = run(:feed, @feed.receive(message))

    # the ChangeFeed topic of one cart's checkout: the payment job publishes to it, the waiting page listens
    def self.topic(cart_id) = "checkout_#{cart_id}"

    def initialize(cart_id:)
      @config = { cart_id: }
      @flash = {}
      @patches = ProgrammingParadigms::Patches.new
      stock_rule = StockStatus.new(low_at: Store::LOW_STOCK_AT)
      shipping = CalculateShipping.new(rates: Store::RATES)
      urls = Rails.application.routes.url_helpers

      products = ProductIndex.new(model: Product, project: ProductRow.new(stock_rule:))
      @items = CartItemsStore.new(model: CartItem, cart_id:)
      @lines = CartLines.new(cart_id:, held: HeldProducts.new(products: ->(ids) { products.lookup(ids) }))
      @pricing = PricingChoices.new(store: CartPricingChoice, cart_id:, shipping:, default_method: :standard,
                                    promo: ValidatePromo.new(codes: Store::PROMO_CODES))
      @totals = CartTotals.new(shipping:, gift_wrap: CalculateGiftWrapCost.new(unit: Store::GIFT_WRAP_CENTS))
      @steps = ProgrammingParadigms::StepRecord.new(record: -> { ::Checkout.for_cart(cart_id) }, flow: FLOW, start: :address, url_edges: URL_EDGES)
      @flow = CheckoutFlow.new(steps: @steps, stock_levels: ->(ids) { Product.stock_levels(ids) }, line_items: BuildLineItems.new(currency: Store::CURRENCY))
      @charge = Charge.new(gateway: Rails.configuration.x.payment_gateway.constantize.new, metadata: ->(id) { { "cart_id" => id } })
      @settle = SettleOrder.new(orders: Order, lines: CartItem, products: Product, cart_id:)
      # every open product list and cart follows the stock; this checkout's page follows the payment
      @publish_stock = ProgrammingParadigms::ChangeFeed::Publish.new(topic: Store::CATALOG_TOPIC, kind: :stock)
      @publish_paid = ProgrammingParadigms::ChangeFeed::Publish.new(topic: self.class.topic(cart_id), kind: :paid, fields: ->(_) { { cart_id: } })
      @publish_declined = ProgrammingParadigms::ChangeFeed::Publish.new(topic: self.class.topic(cart_id), kind: :declined, fields: ->(_) { { cart_id: } })
      @feed = ProgrammingParadigms::ChangeFeed::Subscription.new(topic: self.class.topic(cart_id), kinds: %i[paid declined], url: urls.live_cart_checkout_path)
      @status_html = ->(step) { Partial.render("components/checkout_status", id: STATUS_TARGET, step:, t: TEXTS, pay_url: urls.pay_cart_checkout_path, success_url: urls.cart_success_path) }
    end

    private

    def load_lines = run(:lines, @lines.load(@items.lookup))

    # {part, output} → where it goes
    def wire(part, output, payload)
      case [ part, output ]
      in [ :lines, :contents ] then run(:totals, @totals.contents(payload))
      in [ :pricing, :discount ] then run(:totals, @totals.discount(payload))
      in [ :pricing, :shipping_method ] then run(:totals, @totals.shipping_method(payload))
      in [ :totals, :summary ] then @summary = payload
      # the payment's outcome, on the page waiting for it
      in [ :feed, :paid ] then @patches.replace(STATUS_TARGET, @status_html.(:complete))
      in [ :feed, :declined ] then @patches.replace(STATUS_TARGET, @status_html.(:error))
      end
    end
  end
end
