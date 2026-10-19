module ProgrammingParadigms
  # A multi-step form kept in one record: its `step` column follows a Transitions table, a URL may move
  # it only along url_edges, and the record is the form the steps fill, validated in the context a step
  # names. Config: record (a lambda giving it, called once), flow, start, url_edges. Every answer is the
  # step now showing, and the form where there is one to render. Knows nothing about checkouts or orders.
  # V05's `PersistedSteps` and V07's `StepRecord` are this concept under other names and APIs, extracted
  # separately (2026-10-19).
  class Wizard
    def initialize(record:, flow:, start:, url_edges:) = (@find, @flow, @start, @url_edges = record, flow, start, url_edges)

    def record = @record ||= @find.()
    def step = record.step.to_sym
    def shown = { step:, form: record }
    def restart = (record.update!(step: @start.to_s); { step: @start })

    def visit(requested)
      record.update!(step: requested.to_s) if requested && @url_edges.include?([ step, requested ])
      shown
    end

    def advance(event)
      moved, to = Transitions.step(@flow, step, event)
      record.update!(step: to.to_s) if moved == :moved
      { step: to }
    end

    def validate(params, context) = { form: record.tap { _1.assign_attributes(params); _1.validate(context) } }
    def save(params, context) = record.tap { _1.assign_attributes(params) }.save(context:)
  end
end
