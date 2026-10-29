module Screens
  # The B2B bulk-order portal: the order's lines, the catalogue to add from, the undo offer, volume
  # pricing, and submitting the order with a purchase order number. Its draft is a separate session
  # cart. Built per request; the controllers call one input and read what landed. The order lines,
  # the catalogue records and adding a line are placed by other pages too and stay wired; the steps,
  # the totals and the submission are placed only here, so the page calls them.
  class Portal
    include ProgrammingParadigms::Wiring
    include DomainAbstractions
    include Rules

    FLOW = [ [ :lines, :go_review, :review ], [ :review, :edit_lines, :lines ], [ :review, :submit_order, :submitted ] ].freeze
    URL_EDGES = [ [ :review, :lines ] ].freeze
    MILESTONES = [ [ :lines, "Order" ], [ :review, "Review" ], [ :submitted, "Done" ] ].freeze
    STEP_ORDER = %i[lines review submitted].freeze
    STEP_VIEWS = { lines: "portals/lines", review: "portals/review", submitted: "portals/submitted" }.freeze
    CATALOG_LIST = "portal_products"
    PO_FIELDS = [ [ :po_number, :text, "Purchase order number" ], [ :notes, :text, "Notes (optional)" ] ].freeze
    # subtotal → [percent, label] against the store's tiers (highest first), or [0, nil] below every tier;
    # only this page prices by volume, so the rule stays here as a pure function (ALA Light, §6.28)
    VOLUME_TIER = ->(subtotal) { Store::VOLUME_TIERS.find { |min, _, _| subtotal >= min }&.drop(1) || [ 0, nil ] }
    TEXTS = {
      heading: "Bulk Order Portal", order: "Your order", catalog: "Products", review: "Review order",
      empty: "No lines yet. Add products below.", each: " each", remove: "Remove", add: "Add", default_quantity: 10,
      back: "Back to lines", submit: "Submit order", submitted: "Order submitted", reference: "Reference", items: "items",
      undo_text: "Item removed.", undo: "Undo", summary: Store::SUMMARY_TEXTS,
      notices: { added: "Added to order", restored: "Item restored", empty: "Your order is empty", submitted: "Order submitted" }
    }.freeze
    # the portal's rows carry no gift wrap, saving or wishlist, redraw whole on each request, and are
    # added through AddLine rather than received by the value
    GROUNDED = %i[order.row_added order.row_changed order.row_removed order.saved order.line order.adding items.added
                  catalog.record catalog.form catalog.created catalog.updated catalog.deleted].freeze

    attr_reader :config, :rows, :catalog_rows, :summary, :undo_pending, :flash, :feed, :patches

    def parts = { order: @order, catalog: @catalog, add_line: @add_line, items: @items, feed: @feed }

    def step = @steps.step
    def form = @steps.record
    def reference = @flow.reference

    def show(requested)
      load_lines
      run(:catalog, @catalog.load)
      @steps.show(requested)
    end
    # the order is a value: every input that changes or asks it loads it first
    def add(request) = run(:add_line, @add_line.add(request))
    def set_quantity(change) = (load_lines; run(:order, @order.set_quantity(change)))
    def remove(item_id) = (load_lines; run(:order, @order.remove(item_id)))
    def undo = run(:order, @order.undo)
    def expire_undo = run(:order, @order.expire_undo)
    def edit_lines = @steps.advance(:edit_lines)

    def review
      load_lines
      @flash[:alert] = @say[:empty] if @flow.review(@order.lines)
    end

    # The review step prices the lines beside the form, so validating and submitting load them first.
    def validate(params) = (load_lines; @steps.validate(params, :submit))

    def submit(params)
      load_lines
      @flash[:notice] = @say[:submitted] if @flow.submit(params)
    end

    def live(message) = run(:feed, @feed.receive(message))

    def initialize(cart_id:)
      @config = { cart_id: }
      @flash = {}
      stock_rule = StockStatus.new(low_at: Store::LOW_STOCK_AT)
      urls = Rails.application.routes.url_helpers
      @say = TEXTS[:notices]
      @patches = ProgrammingParadigms::Patches.new
      @dom = Foundation::DomTargets
      labels = Store::STOCK_LABELS

      products = ProductIndex.new(model: Product, project: ProductRow.new(stock_rule:))
      @items = CartItemsStore.new(model: CartItem, cart_id:)
      @order = Features::OrderLines.new(cart_id:, undo_lines: CartItem, undo_window: Store::PORTAL_UNDO_WINDOW,
                                        held: HeldProducts.new(products: ->(ids) { products.lookup(ids) },
                                                               links: ->(id) { { quantity: urls.portal_line_path(id), remove: urls.portal_line_path(id) } }))
      catalog_row = ProductRow.new(stock_rule:, links: ->(_id) { { add: urls.portal_lines_path } })
      @catalog = Records.new(model: Product, project: catalog_row)
      @add_line = AddLine.new(lines: CartItem, cart_id:)
      @totals = OrderTotals.new(shipping: CalculateShipping.new(rates: Store::RATES), volume: VOLUME_TIER, shipping_method: :standard)
      @steps = ProgrammingParadigms::StepRecord.new(record: -> { OrderSubmission.for_cart(cart_id) }, flow: FLOW, start: :lines, url_edges: URL_EDGES)
      @flow = SubmitOrder.new(steps: @steps, cart_id:, orders: Order)
      catalog = ProductIndex.new(model: Product, project: catalog_row)
      @row_html = ->(id) { Partial.each("components/catalog_order_row", catalog.lookup([ id ]).values, t: TEXTS, labels:) }
      @badge_html = ->(fact) { Partial.render("elements/stock_badge", product_id: fact[:product_id], status: stock_rule.(fact[:stock]), stock: fact[:stock], labels:) }
      @feed = ProgrammingParadigms::ChangeFeed::Subscription.new(topic: Store::CATALOG_TOPIC, kinds: %i[product_added product_changed product_removed stock], url: urls.live_portal_path)
    end

    private

    def load_lines = run(:order, @order.load(@items.lookup))

    # {part, output} → where it goes
    def wire(part, output, payload)
      case [ part, output ]
      in [ :order, :changed ] then run(:items, @items.apply(payload))
      in [ :order, :rows ] then @rows = payload
      in [ :order, :contents ] then @summary = @totals.summary(payload)
      in [ :order, :undo_pending ] then @undo_pending = payload
      in [ :order, :restored ] then @flash[:notice] = @say[:restored]
      in [ :catalog, :rows ] then @catalog_rows = payload
      in [ :add_line, :added ] then @flash[:notice] = @say[:added]
      # a change made elsewhere: the catalogue's rows, and every stock badge, order lines' included
      in [ :feed, :product_added ] then @patches.append(CATALOG_LIST, @row_html.(payload[:product_id]))
      in [ :feed, :product_changed ] then @patches.replace(@dom.product_row_id(payload[:product_id]), @row_html.(payload[:product_id]))
      in [ :feed, :product_removed ] then @patches.remove(@dom.product_row_id(payload[:product_id]))
      in [ :feed, :stock ]
        @patches.replace(@dom.product_row_id(payload[:product_id]), @row_html.(payload[:product_id]))
        @patches.replace_all(@dom.stock_selector(payload[:product_id]), @badge_html.(payload))
      end
    end
  end
end
