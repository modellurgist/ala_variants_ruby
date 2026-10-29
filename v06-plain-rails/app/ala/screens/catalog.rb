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

    attr_reader :config, :rows, :row, :form, :saved, :deleted, :notices, :feed

    def parts = { records: @records, add_line: @add_line, product_news: @product_news, product_gone: @product_gone }

    def load = run(:records, @records.load)
    def new = run(:records, @records.new)
    def show(id) = run(:records, @records.show(id))
    def edit(id) = run(:records, @records.edit(id))
    def validate(request) = run(:records, @records.validate(request))
    def save(request) = run(:records, @records.save(request))
    def delete(id) = run(:records, @records.delete(id))
    def add_to_cart(product_id) = run(:add_line, @add_line.add(product_id))

    def initialize(cart_id:)
      @config = { cart_id: }
      @notices = []
      urls = Rails.application.routes.url_helpers
      @project = ProductRow.new(stock_rule: StockStatus.new(low_at: Store::LOW_STOCK_AT),
                                links: ->(id) { { show: urls.product_path(id), edit: urls.edit_product_path(id), delete: urls.product_path(id), add_to_cart: urls.add_to_cart_product_path(id) } })
      @records = Records.new(model: Product, project: @project)
      @add_line = AddLine.new(lines: CartItem, cart_id:)
      # every open catalogue follows a saved or deleted product and a stock change; one product's page, its own
      @product_news = ProgrammingParadigms::ChangeFeed::Publish.new(topic: Topics::CATALOG, kind: :product)
      @product_gone = ProgrammingParadigms::ChangeFeed::Publish.new(topic: Topics::CATALOG, kind: :product_removed)
      @list_feed = ProgrammingParadigms::ChangeFeed::Subscription.new(topic: Topics::CATALOG, kinds: %i[product product_removed stock])
      @row_feed = ProgrammingParadigms::ChangeFeed::Subscription.new(topic: Topics::CATALOG, kinds: %i[product stock])
    end

    private

    # {part, output} → where it goes
    def wire(part, output, payload)
      case [ part, output ]
      in [ :records, :rows ] then @rows = payload; @feed = @list_feed
      in [ :records, :record ] then @row = @project.(payload); @feed = @row_feed.only(product_id: payload.id)
      in [ :records, :form ] then @form = payload
      in [ :records, :created ] then @saved = payload; @notices << TEXTS[:created]; run(:product_news, @product_news.push(product_id: payload.id))
      in [ :records, :updated ] then @saved = payload; @notices << TEXTS[:updated]; run(:product_news, @product_news.push(product_id: payload.id))
      in [ :records, :deleted ] then @deleted = payload; run(:product_gone, @product_gone.push(product_id: payload.id))
      in [ :add_line, :added ] then @notices << TEXTS[:added]
      end
    end
  end
end
