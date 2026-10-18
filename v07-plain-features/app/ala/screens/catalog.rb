module Screens
  # The product catalog: the list with "Add to cart", one product, and the product form. Built per
  # request; the controller calls one input and reads what landed. Every word and number here is
  # this store's.
  class Catalog
    include ProgrammingParadigms::Wiring
    include DomainAbstractions
    include Rules

    STREAM = "catalog"
    MODAL_FRAME = "modal"
    LIST = "products"
    TEXTS = { edit: "Edit", delete: "Delete", confirm_delete: "Delete this product?", add_to_cart: "Add to cart",
              created: "Product created successfully", updated: "Product updated successfully", added: "Added to cart" }.freeze
    GROUNDED = [].freeze

    attr_reader :config, :rows, :row, :form, :saved, :deleted, :notices

    def parts = { records: @records, add_line: @add_line, list_update: @list_update, row_update: @row_update, row_removal: @row_removal }

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
      labels = Store::STOCK_LABELS
      render_row = ->(p) { Partial.render("components/product_row", row: @project.(p), labels:, actions: TEXTS, frame: MODAL_FRAME) }
      # every open catalogue follows a saved or deleted product
      @list_update = ProgrammingParadigms::LiveUpdate.new(stream: STREAM, action: :append, target: LIST, render: render_row)
      @row_update = ProgrammingParadigms::LiveUpdate.new(stream: STREAM, action: :replace, target: ->(p) { Foundation::DomTargets.product_row_id(p.id) }, render: render_row)
      @row_removal = ProgrammingParadigms::LiveUpdate.new(stream: STREAM, action: :remove, target: ->(p) { Foundation::DomTargets.product_row_id(p.id) })
    end

    private

    # {part, output} → where it goes
    def wire(part, output, payload)
      case [ part, output ]
      in [ :records, :rows ] then @rows = payload
      in [ :records, :record ] then @row = @project.(payload)
      in [ :records, :form ] then @form = payload
      in [ :records, :created ] then @saved = payload; @notices << TEXTS[:created]; run(:list_update, @list_update.push(payload))
      in [ :records, :updated ] then @saved = payload; @notices << TEXTS[:updated]; run(:row_update, @row_update.push(payload))
      in [ :records, :deleted ] then @deleted = payload; run(:row_removal, @row_removal.push(payload))
      in [ :add_line, :added ] then @notices << TEXTS[:added]
      end
    end
  end
end
