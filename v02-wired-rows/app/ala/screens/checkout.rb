module Screens
  # Checking out a cart: an address, then payment, which runs as a job, then settling the order. Built
  # per request and once more inside the job (`charge` is the input the job delivers). The flow, its
  # URLs and its words are this screen's; the payment instances carry the store's choices.
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
    TEXTS = { back: "← Back to cart", heading: "Checkout", continue: "Continue to payment", edit_address: "Edit address", pay: "Pay",
              payment_failed: "Payment failed.", try_again: "Try again", processing: "Processing payment…", redirecting: "Redirecting…",
              total: Store::SUMMARY_TEXTS[:total] }.freeze

    attr_reader :config, :step, :form, :summary, :flash, :done

    def parts = { lines: @lines, pricing: @pricing, totals: @totals, flow: @flow, charge: @charge, settle: @settle, products: @products }

    input(:start, ProgrammingParadigms::Event) { @flow.input_port(:start).send_event }
    input(:show, ProgrammingParadigms::DataFlow) do |requested|
      [ @lines, @pricing ].each { _1.input_port(:load).send_event }
      @flow.input_port(:show).push(requested)
    end
    input(:validate, ProgrammingParadigms::DataFlow) { |params| @flow.input_port(:validate).push(params) }
    input(:submit_address, ProgrammingParadigms::DataFlow) { |params| @flow.input_port(:submit_address).push(params) }
    input(:edit_address, ProgrammingParadigms::Event) { @flow.input_port(:edit_address).send_event }
    input(:pay, ProgrammingParadigms::Event) { @flow.input_port(:pay).send_event }
    input(:charge, ProgrammingParadigms::DataFlow) { |payment| @charge.input_port(:charge).push(payment) }

    def self.stream(cart_id) = "checkout_#{cart_id}"

    def initialize(cart_id:)
      @config = { cart_id: }
      @flash = {}
      stock_rule = StockStatus.new(low_at: Store::LOW_STOCK_AT)
      shipping = CalculateShipping.new(rates: Store::RATES)
      urls = Rails.application.routes.url_helpers
      labels = Store::STOCK_LABELS

      @products = ProductIndex.new(model: Product, project: ProductRow.new(stock_rule:))
      @lines = CartLines.new(lines: CartItem, cart_id:)
      @pricing = PricingChoices.new(store: CartPricingChoice, cart_id:, shipping:, default_method: :standard,
                                    promo: ValidatePromo.new(codes: Store::PROMO_CODES))
      @totals = CartTotals.new(shipping:, gift_wrap: CalculateGiftWrapCost.new(unit: Store::GIFT_WRAP_CENTS))
      @flow = CheckoutFlow.new(store: ::Checkout, cart_id:, flow: FLOW, start: :address, url_edges: URL_EDGES,
                               stock_levels: ->(ids) { Product.stock_levels(ids) }, line_items: BuildLineItems.new(currency: Store::CURRENCY))
      @charge = Charge.new(gateway: Rails.configuration.x.payment_gateway.constantize.new, metadata: ->(id) { { "cart_id" => id } })
      @settle = SettleOrder.new(orders: Order, lines: CartItem, products: Product, cart_id:)

      @lines.wire_to(@products, from: :products, to: :lookup)
      @flow.wire_to(@lines, from: :lines, to: :lines)
      @lines.wire_to(@totals, from: :contents, to: :contents)
      @pricing.wire_to(@totals, from: :discount, to: :discount)
      @pricing.wire_to(@totals, from: :shipping_method, to: :shipping_method)
      @totals.on(:summary) { @summary = _1 }

      @flow.on(:step) { @step = _1 }
      @flow.on(:form) { @form = _1 }
      @flow.on(:blocked) { |reason| @flash[:alert] = BLOCKED[reason] }
      @flow.wire_to(ProgrammingParadigms::PushLater.port_for(self, :charge), from: :ready_to_pay)
      @flow.on(:done) { @done = _1 }

      @charge.wire_to(@settle, from: :charged, to: :settle)
      @charge.wire_to(@flow, from: :charged, to: :succeeded)
      @charge.wire_to(@flow, from: :declined, to: :failed)

      @settle.wire_to(ProgrammingParadigms::LiveUpdate.new(stream: Catalog::STREAM, action: :replace_all,
        target: ->(c) { ".#{Foundation::DomTargets.stock_marker(c[:product_id])}" },
        render: ->(c) { Partial.render("elements/stock_badge", product_id: c[:product_id], status: stock_rule.call(c[:stock]), stock: c[:stock], labels:) }),
        from: :stock_changed)
      status = ProgrammingParadigms::LiveUpdate.new(stream: self.class.stream(cart_id), action: :replace, target: STATUS_TARGET,
        render: ->(step) { Partial.render("components/checkout_status", id: STATUS_TARGET, step:, t: TEXTS, pay_url: urls.pay_cart_checkout_path, success_url: urls.cart_success_path) })
      @charge.on(:charged) { status.input_port(:push).push(:complete) }
      @charge.on(:declined) { status.input_port(:push).push(:error) }
    end
  end
end
