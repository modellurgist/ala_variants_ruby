module Screens
  # Checking out a cart: an address, then payment, which runs as a job, then settling the order. Built
  # once per cart and kept; the job delivers `charge` into the kept composition. The flow, its URLs
  # and its words are this screen's; the payment instances carry the store's choices.
  class Checkout
    include Foundation::Ports
    include DomainAbstractions
    include Rules

    FLOW = [ [ :address, :submit_address, :payment ], [ :payment, :edit_address, :address ],
             [ :payment, :pay, :processing ], [ :error, :pay, :processing ],
             [ :processing, :succeeded, :complete ], [ :processing, :failed, :error ] ].freeze
    URL_EDGES = [ [ :payment, :address ] ].freeze
    MILESTONES = [ [ :address, "Address" ], [ :payment, "Payment" ] ].freeze
    STEP_ORDER = %i[address payment processing error complete].freeze
    BLOCKED = { empty: "Your cart is empty", out_of_stock: "Some items are out of stock" }.freeze
    ADDRESS_FIELDS = [ [ :name, :text, "Full name" ], [ :line1, :text, "Address" ], [ :city, :text, "City" ], [ :postal_code, :text, "Postal code" ] ].freeze
    STATUS_TARGET = "checkout_status"
    OUTCOMES = %i[complete error].freeze
    STEP_PARTIALS = { address: "checkouts/address", payment: "checkouts/payment", processing: "checkouts/processing",
                      error: "checkouts/error", complete: "checkouts/complete" }.freeze
    TEXTS = { back: "← Back to cart", heading: "Checkout", continue: "Continue to payment", edit_address: "Edit address", pay: "Pay",
              payment_failed: "Payment failed.", try_again: "Try again", processing: "Processing payment…", redirecting: "Redirecting…",
              total: Store::SUMMARY_TEXTS[:total] }.freeze

    attr_reader :config, :step, :form, :summary, :flash, :done

    def parts = { lines: @lines, pricing: @pricing, totals: @totals, flow: @flow, charge: @charge, settle: @settle, products: @products, items: @items, feed: @feed }
    def live = @feed.subscription

    # Lives across requests (see `LongLived`): `reload` reads the stores again, the flow's step included
    # (a payment job in another process moves it), `begin` opens a request with an empty flash, and each
    # input is one push on what the parts hold.
    input(:reload, ProgrammingParadigms::Event) do
      @lines.input_port(:load).send_event
      @pricing.input_port(:load).send_event
      @flow.input_port(:load).send_event
    end
    input(:begin, ProgrammingParadigms::Event) { @flash = {} }
    input(:start, ProgrammingParadigms::Event) { @flow.input_port(:start).send_event }
    input(:show, ProgrammingParadigms::DataFlow) { |requested| @flow.input_port(:show).push(requested) }
    input(:validate, ProgrammingParadigms::DataFlow) { |params| @flow.input_port(:validate).push(params) }
    input(:submit_address, ProgrammingParadigms::DataFlow) { |params| @flow.input_port(:submit_address).push(params) }
    input(:edit_address, ProgrammingParadigms::Event) { @flow.input_port(:edit_address).send_event }
    input(:pay, ProgrammingParadigms::Event) { @flow.input_port(:pay).send_event }
    input(:charge, ProgrammingParadigms::DataFlow) { |payment| @charge.input_port(:charge).push(payment) }
    input(:live, ProgrammingParadigms::DataFlow) { |message| @feed.input_port(:receive).push(message) }

    # one cart's payment outcome is its own topic: only that cart's checkout page listens
    def self.topic(cart_id) = "checkout_#{cart_id}"

    def initialize(cart_id:)
      @config = { cart_id: }
      @flash = {}
      stock_rule = StockStatus.new(low_at: Store::LOW_STOCK_AT)
      shipping = CalculateShipping.new(rates: Store::RATES)

      @products = ProductIndex.new(model: Product, project: ProductRow.new(stock_rule:))
      @items = CartItemsStore.new(model: CartItem, cart_id:)
      @lines = CartLines.new(cart_id:)
      @pricing = PricingChoices.new(store: CartPricingChoice, cart_id:, shipping:, default_method: :standard,
                                    promo: ValidatePromo.new(codes: Store::PROMO_CODES))
      @totals = CartTotals.new(shipping:, gift_wrap: CalculateGiftWrapCost.new(unit: Store::GIFT_WRAP_CENTS))
      @flow = CheckoutFlow.new(steps: ProgrammingParadigms::PersistedSteps.new(find: -> { ::Checkout.for_cart(cart_id) }, table: FLOW, start: :address, jumps: URL_EDGES),
                               stock_levels: ->(ids) { Product.stock_levels(ids) }, line_items: BuildLineItems.new(currency: Store::CURRENCY))
      @charge = Charge.new(gateway: Rails.configuration.x.payment_gateway.constantize.new, metadata: ->(id) { { "cart_id" => id } })
      @settle = SettleOrder.new(orders: Order, lines: CartItem, products: Product, cart_id:)
      @feed = ProgrammingParadigms::ChangeFeed::Subscription.new(topic: self.class.topic(cart_id), kinds: %i[outcome])

      # the checkout reads the lines and never changes them: their write ports stay open (the wiring test lists them)
      @lines.wire_to(@items, from: :items, to: :lookup)
      @lines.wire_to(@products, from: :products, to: :lookup)
      @flow.wire_to(@lines, from: :lines, to: :lines)
      @lines.wire_to(@totals, from: :contents, to: :contents)
      @pricing.wire_to(@totals, from: :discount, to: :discount)
      @pricing.wire_to(@totals, from: :shipping_method, to: :shipping_method)
      @totals.on(:summary) { @summary = _1 }

      @flow.on(:step) { @step = _1 }
      @flow.on(:form) { @form = _1 }
      @flow.on(:blocked) { |reason| @flash[:alert] = BLOCKED[reason] }
      @flow.wire_to(ProgrammingParadigms::PushLater.port_for(:checkout_screens, cart_id, :charge), from: :ready_to_pay)
      @flow.on(:done) { @done = _1 }

      @charge.wire_to(@settle, from: :charged, to: :settle)
      @charge.wire_to(@flow, from: :charged, to: :succeeded)
      @charge.wire_to(@flow, from: :declined, to: :failed)

      @settle.wire_to(ProgrammingParadigms::ChangeFeed::Publish.new(topic: Store::CATALOG_TOPIC, kind: :stock, fact: ->(level) { level }), from: :stock_changed)
      @charge.wire_to(ProgrammingParadigms::ChangeFeed::Publish.new(topic: self.class.topic(cart_id), kind: :outcome, fact: ->(_) { { cart_id:, step: :complete } }), from: :charged)
      @charge.wire_to(ProgrammingParadigms::ChangeFeed::Publish.new(topic: self.class.topic(cart_id), kind: :outcome, fact: ->(_) { { cart_id:, step: :error } }), from: :declined)
      # the waiting page shows the flow's step, which the payment has moved by now
      @feed.on(:outcome) { @flow.input_port(:show).push(nil) }
    end
  end
end
