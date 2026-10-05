module Screens
  # The product catalog: the list with "Add to cart", one product, and the product form. Built per
  # request; the controller pushes one input and reads what landed. Every word and number here is
  # this store's.
  class Catalog
    include Foundation::Ports
    include DomainAbstractions

    STREAM = "catalog"
    attr_reader :config, :rows, :row, :form, :saved, :deleted, :notices

    def parts = { records: @records, add_line: @add_line }

    input(:load, ProgrammingParadigms::Event) { @records.input_port(:load).send_event }
    input(:new, ProgrammingParadigms::Event) { @records.input_port(:new).send_event }
    input(:edit, ProgrammingParadigms::DataFlow) { |id| @records.input_port(:edit).push(id) }
    input(:validate, ProgrammingParadigms::DataFlow) { |request| @records.input_port(:validate).push(request) }
    input(:save, ProgrammingParadigms::DataFlow) { |request| @records.input_port(:save).push(request) }
    input(:delete, ProgrammingParadigms::DataFlow) { |id| @records.input_port(:delete).push(id) }
    input(:add_to_cart, ProgrammingParadigms::DataFlow) { |product_id| @add_line.input_port(:add).push(product_id) }

    def initialize(cart_id:)
      @config = { cart_id: }
      @notices = []
      project = ProductRow.new(stock_rule: StockStatus.new(low_at: Store::LOW_STOCK_AT))
      @records = Records.new(model: Product, project:)
      @add_line = AddLine.new(lines: CartItem, cart_id:)
      labels = Store::STOCK_LABELS

      @records.on(:rows) { @rows = _1 }
      @records.on(:form) { |record| @form = record; @row = project.(record) if record.persisted? }
      @records.on(:saved) { @saved = _1 }
      @records.on(:saved) { |p| @notices << (p.previously_new_record? ? "Product created successfully" : "Product updated successfully") }
      @records.on(:deleted) { @deleted = _1 }
      @add_line.on(:added) { @notices << "Added to cart" }

      helpers = ApplicationController.helpers
      @records.wire_to(Foundation::LiveUpdate.new(stream: STREAM, action: :replace, target: ->(p) { helpers.product_row_id(p.id) },
        render: ->(p) { Foundation::LiveUpdate.component(:product_row, row: project.(p), labels:) }), from: :saved)
      @records.wire_to(Foundation::LiveUpdate.new(stream: STREAM, action: :append, target: "products",
        render: ->(p) { Foundation::LiveUpdate.component(:product_row, row: project.(p), labels:) }), from: :saved)
      @records.wire_to(Foundation::LiveUpdate.new(stream: STREAM, action: :remove, target: ->(p) { helpers.product_row_id(p.id) }), from: :deleted)
    end
  end
end
