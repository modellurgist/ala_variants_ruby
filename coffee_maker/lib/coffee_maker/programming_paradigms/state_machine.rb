module ProgrammingParadigms
  # Spray's simple state machine paradigm (§2.9.2): a current state, a table of [from, event, to], one
  # event input port per event, and a dataflow output carrying the state whenever it changes.
  # Config: transitions ([[from, event, to], ...]), start.
  class StateMachine
    include Foundation::Ports
    output :state, DataFlow, many: true

    def initialize(transitions:, start:)
      @transitions, @current = transitions, start
      transitions.map { _2 }.uniq.each do |event|
        self.class.inputs[event] = Event
        define_singleton_method(:"#{event}_received") { fire(event) }
      end
    end

    def current = @current

    private

    def fire(event)
      to = @transitions.find { |from, ev, _| from == @current && ev == event }&.last
      return unless to && to != @current
      @current = to
      emit(:state, to)
    end
  end
end
