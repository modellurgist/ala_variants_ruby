module DomainAbstractions
  # A persistent table with a record form: lists its rows, shows or opens a record, validates, saves
  # and deletes, for any Active Record model. Config: model, project (a record to the row a list
  # shows). In: load, new, show and edit (an id), validate and save ({ id:, attrs: }; a nil id means
  # a new record), delete (an id). Out: rows (all records, projected, on load), record (the record
  # asked for by show), form (a record to render, with its errors when it has any), created and
  # updated (a record after a successful save), deleted (the record removed).
  class Records
    OUTPUTS = %i[rows record form created updated deleted].freeze

    def load = { rows: @model.order(:id).map { @project.(_1) } }
    def new = { form: @model.new }
    def show(id) = { record: @model.find(id) }
    def edit(id) = { form: @model.find(id) }
    def validate(r) = { form: build(r).tap(&:validate) }
    def delete(id) = { deleted: @model.find(id).tap(&:destroy!) }

    def save(r)
      record = build(r)
      new_record = record.new_record?
      return { form: record } unless record.save
      { (new_record ? :created : :updated) => record }
    end

    def initialize(model:, project:) = (@model, @project = model, project)

    private

    def build(request)
      record = request[:id] ? @model.find(request[:id]) : @model.new
      record.tap { _1.assign_attributes(request[:attrs]) }
    end
  end
end
