module Screens
  # The B2B bulk-order portal: the order's lines, the catalogue to add from, the undo offer, volume
  # pricing, and submitting the order with a purchase order number. Its draft is a separate session
  # cart. Built per request; the controllers push one input and read what landed.
  class Portal
    include Foundation::Ports
    include DomainAbstractions

    FLOW = [ [ :lines, :go_review, :review ], [ :review, :edit_lines, :lines ], [ :review, :submit_order, :submitted ] ].freeze
    URL_EDGES = [ [ :review, :lines ] ].freeze
    MILESTONES = [ [ :lines, "Order" ], [ :review, "Review" ], [ :submitted, "Done" ] ].freeze
    PO_FIELDS = [ [ :po_number, :text, "Purchase order number" ], [ :notes, :text, "Notes (optional)" ] ].freeze
    TEXTS = {
      heading: "Bulk Order Portal", order: "Your order", catalog: "Products", review: "Review order",
      empty: "No lines yet. Add products below.", each: " each", remove: "Remove", add: "Add", default_quantity: 10,
      back: "Back to lines", submit: "Submit order", submitted: "Order submitted", reference: "Reference", items: "items",
      undo_text: "Item removed.", undo: "Undo", summary: Store::SUMMARY_TEXTS
    }.freeze

    attr_reader :config, :step, :rows, :catalog_rows, :summary, :form, :reference, :undo_pending, :flash

    def parts = { lines: @lines, undo: @undo, catalog: @catalog, add_line: @add_line, totals: @totals, flow: @flow }

    input(:show, ProgrammingParadigms::DataFlow) do |requested|
      [ @undo, @lines, @catalog ].each { _1.input_port(:load).send_event }
      @flow.input_port(:show).push(requested)
    end
    input(:add, ProgrammingParadigms::DataFlow) { |request| @add_line.input_port(:add).push(request) }
    input(:set_quantity, ProgrammingParadigms::DataFlow) { |change| @lines.input_port(:set_quantity).push(change) }
    input(:remove, ProgrammingParadigms::DataFlow) { |item_id| @lines.input_port(:remove).push(item_id) }
    input(:undo, ProgrammingParadigms::Event) { @undo.input_port(:restore).send_event }
    input(:expire_undo, ProgrammingParadigms::Event) { @undo.input_port(:expire).send_event }
    input(:review, ProgrammingParadigms::Event) { @flow.input_port(:review).send_event }
    input(:edit_lines, ProgrammingParadigms::Event) { @flow.input_port(:edit_lines).send_event }
    input(:validate, ProgrammingParadigms::DataFlow) { |params| @flow.input_port(:validate).push(params) }
    input(:submit, ProgrammingParadigms::DataFlow) { |params| @flow.input_port(:submit).push(params) }

    def initialize(cart_id:)
      @config = { cart_id: }
      @flash = {}
      stock_rule = StockStatus.new(low_at: Store::LOW_STOCK_AT)

      @lines = CartLines.new(lines: CartItem, cart_id:, stock_rule:)
      @undo = Undo.new(lines: CartItem, cart_id:, window: Store::UNDO_WINDOW)
      @catalog = Records.new(model: Product, project: ProductRow.new(stock_rule:))
      @add_line = AddLine.new(lines: CartItem, cart_id:)
      @totals = OrderTotals.new(shipping: CalculateShipping.new(rates: Store::RATES), volume: VolumeTier.new(tiers: Store::VOLUME_TIERS), shipping_method: :standard)
      @flow = SubmitOrder.new(store: OrderSubmission, cart_id:, flow: FLOW, start: :lines, url_edges: URL_EDGES, orders: Order)

      @lines.on(:rows) { @rows = _1 }
      @lines.wire_to(@totals, from: :contents, to: :contents)
      @lines.wire_to(@undo, from: :removed, to: :capture)
      @undo.on(:pending) { @undo_pending = _1 }
      @catalog.on(:rows) { @catalog_rows = _1 }
      @add_line.on(:added) { say :notice, "Added to order" }
      @totals.on(:summary) { @summary = _1 }

      @flow.wire_to(@lines, from: :lines, to: :lines)
      @flow.on(:step) { @step = _1 }
      @flow.on(:form) { @form = _1 }
      @flow.on(:blocked) { say :alert, "Your order is empty" }
      @flow.on(:reference) { @reference = _1 }
      @flow.on(:reference) { say :notice, "Order submitted" }
    end

    private

    def say(kind, text) = @flash[kind] = text
  end
end
