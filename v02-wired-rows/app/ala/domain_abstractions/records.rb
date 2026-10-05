module DomainAbstractions
  # A persistent table with a record form: lists its rows, shows or opens a record, validates, saves
  # and deletes, for any Active Record model. Config: model, project (a record to the row a list
  # shows). Ports in: load, new, show and edit (an id), validate and save ({ id:, attrs: }; a nil id
  # means a new record), delete (an id). Ports out: rows (all records, projected, on load), record
  # (the record asked for by show), form (a record to render, with its errors when it has any),
  # created and updated (a record after a successful save), deleted (the record removed).
  class Records
    include Foundation::Ports
    output :rows, ProgrammingParadigms::DataFlow
    output :record, ProgrammingParadigms::DataFlow
    output :form, ProgrammingParadigms::DataFlow
    output :created, ProgrammingParadigms::DataFlow, many: true
    output :updated, ProgrammingParadigms::DataFlow, many: true
    output :deleted, ProgrammingParadigms::DataFlow, many: true

    input(:load, ProgrammingParadigms::Event) { emit(:rows, @model.order(:id).map { @project.(_1) }) }
    input(:new, ProgrammingParadigms::Event) { emit(:form, @model.new) }
    input(:show, ProgrammingParadigms::DataFlow) { |id| emit(:record, @model.find(id)) }
    input(:edit, ProgrammingParadigms::DataFlow) { |id| emit(:form, @model.find(id)) }
    input(:validate, ProgrammingParadigms::DataFlow) { |r| emit(:form, build(r).tap(&:validate)) }
    input(:delete, ProgrammingParadigms::DataFlow) { |id| emit(:deleted, @model.find(id).tap(&:destroy!)) }
    input(:save, ProgrammingParadigms::DataFlow) do |r|
      record = build(r)
      new_record = record.new_record?
      next emit(:form, record) unless record.save
      emit(new_record ? :created : :updated, record)
    end

    def initialize(model:, project:) = (@model, @project = model, project)

    private

    def build(request)
      record = request[:id] ? @model.find(request[:id]) : @model.new
      record.tap { _1.assign_attributes(request[:attrs]) }
    end
  end
end
