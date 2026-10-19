module ProgrammingParadigms
  # The state-machine paradigm with its state kept in a record's `step` column, so a flow outlives the
  # request and the process that moved it. Config: find (a lambda giving the record, read once and
  # kept until `reload`, which a kept flow needs when another process may have moved the step), table ([[from, event, to]], stepped by `Transitions`), start, jumps (the [from, to] moves a
  # URL may ask for). The flow that owns the steps keeps its form in the same `record`. V06's `Wizard`
  # and V07's `StepRecord` are this concept under other names and APIs, extracted separately (2026-10-19).
  class PersistedSteps
    def initialize(find:, table:, start:, jumps:) = (@find, @table, @start, @jumps = find, table, start, jumps)

    def record = @record ||= @find.()
    def reload = @record = @find.()
    def now = record.step.to_sym
    def restart = to(@start)

    def fire(event)
      moved, step = Transitions.step(@table, now, event)
      moved == :moved ? to(step) : step
    end

    def jump(requested) = requested && @jumps.include?([ now, requested ]) ? to(requested) : now

    private

    def to(step)
      record.update!(step: step.to_s)
      step
    end
  end
end
