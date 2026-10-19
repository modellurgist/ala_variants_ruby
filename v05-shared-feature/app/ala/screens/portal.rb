module Screens
  # The B2B bulk-order portal: the order's lines, the catalogue to add from, the undo offer, volume
  # pricing, and submitting the order with a purchase order number. Its draft is a separate session
  # cart. Built per request; the controllers push one input and read what landed.
  class Portal
    include Foundation::Ports
    include DomainAbstractions
    include Rules

    FLOW = [ [ :lines, :go_review, :review ], [ :review, :edit_lines, :lines ], [ :review, :submit_order, :submitted ] ].freeze
    URL_EDGES = [ [ :review, :lines ] ].freeze
    MILESTONES = [ [ :lines, "Order" ], [ :review, "Review" ], [ :submitted, "Done" ] ].freeze
    STEP_ORDER = %i[lines review submitted].freeze
    PO_FIELDS = [ [ :po_number, :text, "Purchase order number" ], [ :notes, :text, "Notes (optional)" ] ].freeze
    TEXTS = {
      heading: "Bulk Order Portal", order: "Your order", catalog: "Products", review: "Review order",
      empty: "No lines yet. Add products below.", each: " each", remove: "Remove", add: "Add", default_quantity: 10,
      back: "Back to lines", submit: "Submit order", submitted: "Order submitted", reference: "Reference", items: "items",
      undo_text: "Item removed.", undo: "Undo", summary: Store::SUMMARY_TEXTS,
      notices: { added: "Added to order", restored: "Item restored", empty: "Your order is empty", submitted: "Order submitted" }
    }.freeze

    attr_reader :config, :step, :rows, :catalog_rows, :summary, :form, :reference, :undo_pending, :flash

    def parts = { order: @order, catalog: @catalog, add_line: @add_line, totals: @totals, flow: @flow, products: @products, items: @items }

    input(:show, ProgrammingParadigms::DataFlow) do |requested|
      @order.input_port(:load).send_event
      @catalog.input_port(:load).send_event
      @flow.input_port(:show).push(requested)
    end
    # the order is a value and this screen is built per request: every input that changes or asks it loads it first
    input(:add, ProgrammingParadigms::DataFlow) { |request| @add_line.input_port(:add).push(request) }
    input(:set_quantity, ProgrammingParadigms::DataFlow) { |change| @order.input_port(:load).send_event; @order.input_port(:set_quantity).push(change) }
    input(:remove, ProgrammingParadigms::DataFlow) { |item_id| @order.input_port(:load).send_event; @order.input_port(:remove).push(item_id) }
    input(:undo, ProgrammingParadigms::Event) { @order.input_port(:undo).send_event }
    input(:expire_undo, ProgrammingParadigms::Event) { @order.input_port(:expire_undo).send_event }
    input(:review, ProgrammingParadigms::Event) { @order.input_port(:load).send_event; @flow.input_port(:review).send_event }
    input(:edit_lines, ProgrammingParadigms::Event) { @flow.input_port(:edit_lines).send_event }
    # The review step prices the lines beside the form, so validating and submitting load them first.
    input(:validate, ProgrammingParadigms::DataFlow) do |params|
      @order.input_port(:load).send_event
      @flow.input_port(:validate).push(params)
    end
    input(:submit, ProgrammingParadigms::DataFlow) do |params|
      @order.input_port(:load).send_event
      @flow.input_port(:submit).push(params)
    end

    def initialize(cart_id:)
      @config = { cart_id: }
      @flash = {}
      stock_rule = StockStatus.new(low_at: Store::LOW_STOCK_AT)
      urls = Rails.application.routes.url_helpers
      say = TEXTS[:notices]

      @products = ProductIndex.new(model: Product, project: ProductRow.new(stock_rule:))
      @items = CartItemsStore.new(model: CartItem, cart_id:)
      @order = Features::OrderLines.new(cart_id:, undo_lines: CartItem, undo_window: Store::PORTAL_UNDO_WINDOW,
                                        row: LineRow.new(fields: %i[name thumbnail amount stock stock_status],
                                                         links: ->(id) { { quantity: urls.portal_line_path(id), remove: urls.portal_line_path(id) } }))
      @catalog = Records.new(model: Product, project: ProductRow.new(stock_rule:, links: ->(_id) { { add: urls.portal_lines_path } }))
      @add_line = AddLine.new(lines: CartItem, cart_id:)
      @totals = OrderTotals.new(shipping: CalculateShipping.new(rates: Store::RATES), volume: VolumeTier.new(tiers: Store::VOLUME_TIERS), shipping_method: :standard)
      @flow = SubmitOrder.new(steps: ProgrammingParadigms::PersistedSteps.new(find: -> { OrderSubmission.for_cart(cart_id) }, table: FLOW, start: :lines, jumps: URL_EDGES),
                              cart_id:, orders: Order)

      @order.wire_to(@items, from: :items, to: :lookup)
      @order.wire_to(@products, from: :products, to: :lookup)
      @order.wire_to(@items, from: :changed, to: :apply)
      @order.wire_to(@items, from: :adding, to: :add)
      @order.wire_to(@items, from: :fetch, to: :fetch)
      @items.wire_to(@order, from: :added, to: :arrived)
      @items.wire_to(@order, from: :found, to: :arrived)
      @order.on(:rows) { @rows = _1 }
      @order.wire_to(@totals, from: :contents, to: :contents)
      @order.on(:undo_pending) { @undo_pending = _1 }
      @order.on(:restored) { @flash[:notice] = say[:restored] }
      @catalog.on(:rows) { @catalog_rows = _1 }
      @add_line.on(:added) { @flash[:notice] = say[:added] }
      @totals.on(:summary) { @summary = _1 }

      @flow.wire_to(@order, from: :lines, to: :lines)
      @flow.on(:step) { @step = _1 }
      @flow.on(:form) { @form = _1 }
      @flow.on(:blocked) { @flash[:alert] = say[:empty] }
      @flow.on(:reference) { @reference = _1 }
      @flow.on(:reference) { @flash[:notice] = say[:submitted] }
    end
  end
end
