module DomainAbstractions
  # A persistent table with a record form: lists its rows, opens a record for editing, validates,
  # saves and deletes, for any Active Record model. Config: model, project (a record to the row a list
  # shows). Ports out: rows (all records, projected, on load), form (a record to render, with its
  # errors when it has any), saved (a record after a successful save), deleted (the record removed).
  # A save or validate request is { id:, attrs: }; a nil id means a new record.
  class Records
    include Foundation::Ports
    output :rows, ProgrammingParadigms::DataFlow
    output :form, ProgrammingParadigms::DataFlow
    output :saved, ProgrammingParadigms::DataFlow, many: true
    output :deleted, ProgrammingParadigms::DataFlow, many: true

    input(:load, ProgrammingParadigms::Event) { emit(:rows, @model.order(:id).map { @project.(_1) }) }
    input(:new, ProgrammingParadigms::Event) { emit(:form, @model.new) }
    input(:edit, ProgrammingParadigms::DataFlow) { |id| emit(:form, @model.find(id)) }
    input(:validate, ProgrammingParadigms::DataFlow) { |r| emit(:form, build(r).tap(&:validate)) }
    input(:delete, ProgrammingParadigms::DataFlow) { |id| emit(:deleted, @model.find(id).tap(&:destroy!)) }
    input(:save, ProgrammingParadigms::DataFlow) do |r|
      record = build(r)
      record.save ? emit(:saved, record) : emit(:form, record)
    end

    def initialize(model:, project:) = (@model, @project = model, project)

    private

    def build(request)
      record = request[:id] ? @model.find(request[:id]) : @model.new
      record.tap { _1.assign_attributes(request[:attrs]) }
    end
  end
end
