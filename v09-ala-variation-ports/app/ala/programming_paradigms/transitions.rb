module ProgrammingParadigms
  # The state-machine paradigm (§4.16): a table of [from, event, to] and a current state. Stepping
  # with an event moves along a listed transition or stays put. Knows nothing about checkouts or orders.
  module Transitions
    # Returns [:moved, to] or [:stayed, state].
    def self.step(table, state, event)
      row = table.find { |from, ev, _to| from == state && ev == event }
      row ? [ :moved, row[2] ] : [ :stayed, state ]
    end
  end
end
