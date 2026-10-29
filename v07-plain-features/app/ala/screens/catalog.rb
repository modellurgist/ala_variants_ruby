module Screens
  # The product catalog: the list with "Add to cart", one product, and the product form. Built per
  # request; the controller calls one input and reads what landed. Every word and number here is
  # this store's.
  class Catalog
    include ProgrammingParadigms::Wiring
    include DomainAbstractions
    include Rules

    MODAL_FRAME = "modal"
    LIST = "products"
    TEXTS = { edit: "Edit", delete: "Delete", confirm_delete: "Delete this product?", add_to_cart: "Add to cart",
              created: "Product created successfully", updated: "Product updated successfully", added: "Added to cart" }.freeze
    GROUNDED = [].freeze

    attr_reader :config, :rows, :row, :form, :saved, :deleted, :notices, :feed, :patches

    def parts = { records: @records, add_line: @add_line, feed: @feed, publish_added: @publish_added, publish_changed: @publish_changed,
                  publish_removed: @publish_removed, publish_stock: @publish_stock }

    def load = run(:records, @records.load)
    def new = run(:records, @records.new)
    def show(id) = run(:records, @records.show(id))
    def edit(id) = run(:records, @records.edit(id))
    def validate(request) = run(:records, @records.validate(request))
    def save(request) = run(:records, @records.save(request))
    def delete(id) = run(:records, @records.delete(id))
    def add_to_cart(product_id) = run(:add_line, @add_line.add(product_id))
    def live(message) = run(:feed, @feed.receive(message))

    def initialize(cart_id:)
      @config = { cart_id: }
      @notices = []
      @patches = ProgrammingParadigms::Patches.new
      @dom = Foundation::DomTargets
      urls = Rails.application.routes.url_helpers
      stock_rule = StockStatus.new(low_at: Store::LOW_STOCK_AT)
      @project = ProductRow.new(stock_rule:,
                                links: ->(id) { { show: urls.product_path(id), edit: urls.edit_product_path(id), delete: urls.product_path(id), add_to_cart: urls.add_to_cart_product_path(id) } })
      @records = Records.new(model: Product, project: @project)
      @add_line = AddLine.new(lines: CartItem, cart_id:)
      labels = Store::STOCK_LABELS
      products = ProductIndex.new(model: Product, project: @project)
      @row_html = ->(id) { Partial.each("components/product_row", products.lookup([ id ]).values, labels:, actions: TEXTS, frame: MODAL_FRAME) }
      @badge_html = ->(fact) { Partial.render("elements/stock_badge", product_id: fact[:product_id], status: stock_rule.(fact[:stock]), stock: fact[:stock], labels:) }
      # a save or delete here reaches every open product list, and a staff stock edit every open cart
      identity = ->(product) { { product_id: product.id } }
      @publish_added = ProgrammingParadigms::ChangeFeed::Publish.new(topic: Store::CATALOG_TOPIC, kind: :product_added, fields: identity)
      @publish_changed = ProgrammingParadigms::ChangeFeed::Publish.new(topic: Store::CATALOG_TOPIC, kind: :product_changed, fields: identity)
      @publish_removed = ProgrammingParadigms::ChangeFeed::Publish.new(topic: Store::CATALOG_TOPIC, kind: :product_removed, fields: identity)
      @publish_stock = ProgrammingParadigms::ChangeFeed::Publish.new(topic: Store::CATALOG_TOPIC, kind: :stock, fields: ->(product) { { product_id: product.id, stock: product.stock } })
      @feed = ProgrammingParadigms::ChangeFeed::Subscription.new(topic: Store::CATALOG_TOPIC, kinds: %i[product_added product_changed product_removed stock], url: urls.live_products_path)
    end

    private

    # {part, output} → where it goes
    def wire(part, output, payload)
      case [ part, output ]
      in [ :records, :rows ] then @rows = payload
      in [ :records, :record ] then @row = @project.(payload)
      in [ :records, :form ] then @form = payload
      in [ :records, :created ] then @saved = payload; @notices << TEXTS[:created]; run(:publish_added, @publish_added.push(payload))
      in [ :records, :updated ]
        @saved = payload
        @notices << TEXTS[:updated]
        run(:publish_changed, @publish_changed.push(payload))
        run(:publish_stock, @publish_stock.push(payload))
      in [ :records, :deleted ] then @deleted = payload; run(:publish_removed, @publish_removed.push(payload))
      in [ :add_line, :added ] then @notices << TEXTS[:added]
      # a change made elsewhere, on this page
      in [ :feed, :product_added ] then @patches.append(LIST, @row_html.(payload[:product_id]))
      in [ :feed, :product_changed ] then @patches.replace(@dom.product_row_id(payload[:product_id]), @row_html.(payload[:product_id]))
      in [ :feed, :product_removed ] then @patches.remove(@dom.product_row_id(payload[:product_id]))
      in [ :feed, :stock ] then @patches.replace_all(@dom.stock_selector(payload[:product_id]), @badge_html.(payload))
      end
    end
  end
end
