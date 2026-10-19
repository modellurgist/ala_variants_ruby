module Screens
  # The B2B bulk-order portal: the order's lines, the catalogue to add from, the undo offer, volume
  # pricing, and submitting the order with a purchase order number. Its draft is a separate session
  # cart. Built per request; the controllers call one input and read what landed.
  class Portal
    include ProgrammingParadigms::Wiring
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
    # the portal's rows carry no gift wrap, saving or wishlist, redraw whole on each request, and are
    # added through AddLine rather than received by the value
    GROUNDED = %i[lines.row_added lines.row_changed lines.row_removed lines.saved lines.line lines.adding items.added
                  catalog.record catalog.form catalog.created catalog.updated catalog.deleted].freeze

    attr_reader :config, :step, :rows, :catalog_rows, :summary, :form, :reference, :undo_pending, :flash

    def parts = { lines: @lines, undo: @undo, catalog: @catalog, add_line: @add_line, totals: @totals, flow: @flow, items: @items }

    def show(requested)
      run(:undo, @undo.load)
      load_lines
      run(:catalog, @catalog.load)
      run(:flow, @flow.show(requested))
    end
    # the lines are a value: every input that changes or asks them loads them first
    def add(request) = run(:add_line, @add_line.add(request))
    def set_quantity(change) = (load_lines; run(:lines, @lines.set_quantity(change)))
    def remove(item_id) = (load_lines; run(:lines, @lines.remove(item_id)))
    def undo = run(:undo, @undo.restore)
    def expire_undo = run(:undo, @undo.expire)
    def review = (load_lines; run(:flow, @flow.review(@lines.lines)))
    def edit_lines = run(:flow, @flow.edit_lines)
    # The review step prices the lines beside the form, so validating and submitting load them first.
    def validate(params) = (load_lines; run(:flow, @flow.validate(params)))
    def submit(params) = (load_lines; run(:flow, @flow.submit(params)))

    def initialize(cart_id:)
      @config = { cart_id: }
      @flash = {}
      stock_rule = StockStatus.new(low_at: Store::LOW_STOCK_AT)
      urls = Rails.application.routes.url_helpers
      @say = TEXTS[:notices]

      products = ProductIndex.new(model: Product, project: ProductRow.new(stock_rule:))
      @items = CartItemsStore.new(model: CartItem, cart_id:)
      @lines = CartLines.new(cart_id:, rows: LineRow.new(products: ->(ids) { products.lookup(ids) }, links: ->(id) { { quantity: urls.portal_line_path(id), remove: urls.portal_line_path(id) } }))
      @undo = Undo.new(lines: CartItem, cart_id:, window: Store::UNDO_WINDOW)
      @catalog = Records.new(model: Product, project: ProductRow.new(stock_rule:, links: ->(_id) { { add: urls.portal_lines_path } }))
      @add_line = AddLine.new(lines: CartItem, cart_id:)
      @totals = OrderTotals.new(shipping: CalculateShipping.new(rates: Store::RATES), volume: VolumeTier.new(tiers: Store::VOLUME_TIERS), shipping_method: :standard)
      @flow = SubmitOrder.new(steps: ProgrammingParadigms::Wizard.new(record: -> { OrderSubmission.for_cart(cart_id) }, flow: FLOW, start: :lines, url_edges: URL_EDGES),
                              cart_id:, orders: Order)
    end

    private

    def load_lines = run(:lines, @lines.load(@items.lookup))

    # {part, output} → where it goes
    def wire(part, output, payload)
      case [ part, output ]
      in [ :lines, :changed ] then run(:items, @items.apply(payload))
      in [ :lines, :rows ] then @rows = payload
      in [ :lines, :contents ] then run(:totals, @totals.contents(payload))
      in [ :lines, :removed ] then run(:undo, @undo.capture(payload))
      in [ :undo, :pending ] then @undo_pending = payload
      in [ :undo, :restored ] then @flash[:notice] = @say[:restored]
      in [ :catalog, :rows ] then @catalog_rows = payload
      in [ :add_line, :added ] then @flash[:notice] = @say[:added]
      in [ :totals, :summary ] then @summary = payload
      in [ :flow, :step ] then @step = payload
      in [ :flow, :form ] then @form = payload
      in [ :flow, :blocked ] then @flash[:alert] = @say[:empty]
      in [ :flow, :reference ] then @reference = payload; @flash[:notice] = @say[:submitted]
      end
    end
  end
end
