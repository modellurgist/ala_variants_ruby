module ProgrammingParadigms
  # A Transitions machine (§4.16) kept in the `step` column of one stored record, which is also the
  # form its steps fill in. Answers in outputs: step (the step now) and form (the record to render).
  # Config: record (a lambda answering the record, asked once), flow ([[from, event, to]]), start,
  # url_edges (the [from, to] jumps a URL may make). V05's `PersistedSteps` and V06's `Wizard` are this
  # concept under other names and APIs, extracted separately (2026-10-19).
  class StepRecord
    def restart = (record.update!(step: @start.to_s); { step: @start })

    # The URL asks for a step: honour it along an allowed jump, otherwise stay.
    def show(requested)
      record.update!(step: requested.to_s) if requested && @url_edges.include?([ step, requested ])
      { step:, form: record }
    end

    def advance(event)
      moved, to = Transitions.step(@flow, step, event)
      record.update!(step: to.to_s) if moved == :moved
      { step: to }
    end

    def validate(params, context) = { form: record.tap { _1.assign_attributes(params); _1.validate(context) } }

    # Saved in the validation context, the record moves on by the event, with whatever the block
    # answers for the saved record; otherwise it stays, the form carrying its errors.
    def submit(params, context:, event:)
      record.assign_attributes(params)
      return { step:, form: record } unless record.save(context:)
      also = block_given? ? yield(record) : {}
      advance(event).merge(also)
    end

    def step = record.step.to_sym
    def record = @record ||= @find.()

    def initialize(record:, flow:, start:, url_edges:) = (@find, @flow, @start, @url_edges = record, flow, start, url_edges)
  end
end
