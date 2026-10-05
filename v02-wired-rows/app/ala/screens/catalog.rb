module Screens
  # The product catalog: the list with "Add to cart", one product, and the product form. Built per
  # request; the controller pushes one input and reads what landed. Every word and number here is
  # this store's.
  class Catalog
    include Foundation::Ports
    include DomainAbstractions
    include Rules

    STREAM = "catalog"
    MODAL_FRAME = "modal"
    LIST = "products"
    TEXTS = { edit: "Edit", delete: "Delete", confirm_delete: "Delete this product?", add_to_cart: "Add to cart",
              created: "Product created successfully", updated: "Product updated successfully", added: "Added to cart" }.freeze

    attr_reader :config, :rows, :row, :form, :saved, :deleted, :notices

    def parts = { records: @records, add_line: @add_line }

    input(:load, ProgrammingParadigms::Event) { @records.input_port(:load).send_event }
    input(:new, ProgrammingParadigms::Event) { @records.input_port(:new).send_event }
    input(:show, ProgrammingParadigms::DataFlow) { |id| @records.input_port(:show).push(id) }
    input(:edit, ProgrammingParadigms::DataFlow) { |id| @records.input_port(:edit).push(id) }
    input(:validate, ProgrammingParadigms::DataFlow) { |request| @records.input_port(:validate).push(request) }
    input(:save, ProgrammingParadigms::DataFlow) { |request| @records.input_port(:save).push(request) }
    input(:delete, ProgrammingParadigms::DataFlow) { |id| @records.input_port(:delete).push(id) }
    input(:add_to_cart, ProgrammingParadigms::DataFlow) { |product_id| @add_line.input_port(:add).push(product_id) }

    def initialize(cart_id:)
      @config = { cart_id: }
      @notices = []
      urls = Rails.application.routes.url_helpers
      project = ProductRow.new(stock_rule: StockStatus.new(low_at: Store::LOW_STOCK_AT),
                               links: ->(id) { { show: urls.product_path(id), edit: urls.edit_product_path(id), delete: urls.product_path(id), add_to_cart: urls.add_to_cart_product_path(id) } })
      @records = Records.new(model: Product, project:)
      @add_line = AddLine.new(lines: CartItem, cart_id:)
      labels = Store::STOCK_LABELS
      render_row = ->(p) { Partial.render("components/product_row", row: project.(p), labels:, actions: TEXTS, frame: MODAL_FRAME) }

      @records.on(:rows) { @rows = _1 }
      @records.on(:record) { @row = project.(_1) }
      @records.on(:form) { @form = _1 }
      @records.on(:created) { @saved = _1 }
      @records.on(:updated) { @saved = _1 }
      @records.on(:created) { @notices << TEXTS[:created] }
      @records.on(:updated) { @notices << TEXTS[:updated] }
      @records.on(:deleted) { @deleted = _1 }
      @add_line.on(:added) { @notices << TEXTS[:added] }

      @records.wire_to(ProgrammingParadigms::LiveUpdate.new(stream: STREAM, action: :append, target: LIST, render: render_row), from: :created)
      @records.wire_to(ProgrammingParadigms::LiveUpdate.new(stream: STREAM, action: :replace, target: ->(p) { Foundation::DomTargets.product_row_id(p.id) }, render: render_row), from: :updated)
      @records.wire_to(ProgrammingParadigms::LiveUpdate.new(stream: STREAM, action: :remove, target: ->(p) { Foundation::DomTargets.product_row_id(p.id) }), from: :deleted)
    end
  end
end
