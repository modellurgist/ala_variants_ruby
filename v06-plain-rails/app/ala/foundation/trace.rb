module Foundation
  # The wiring as it ran: every hop a composition routed while the trace was on, by composition class,
  # from an output ([part, output], or :outside for a request) to a part, or to :screen when an arm
  # kept it. A test run turns it on; off, nothing is recorded.
  module Trace
    module_function

    def enable = @hops = Hash.new(0)
    def enabled? = !@hops.nil?
    def hop(composition, from, to) = @hops[[ composition.name, from, to ]] += 1
    def edges(composition) = (@hops || {}).keys.select { _1[0] == composition.name }.map { _1.drop(1) }.uniq
  end
end
