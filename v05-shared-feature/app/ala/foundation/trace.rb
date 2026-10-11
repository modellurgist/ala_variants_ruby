module Foundation
  # The wiring as it ran: every hop an output made while the trace was on, counted by the sender's
  # class, the output, what it reached and the input. A test run turns it on; off, `hop` is never
  # reached, so a running application pays nothing. What to make of the hops (a drawing, a list of
  # wires that never carried anything) is a paradigm's business, with the built graph in hand.
  module Trace
    module_function

    def enable = @hops = Hash.new(0)
    def enabled? = !@hops.nil?
    def hops = @hops || {}

    def hop(sender, wire) = @hops[key(sender, wire)] += 1
    def fired?(sender, wire) = hops.key?(key(sender, wire))

    def key(sender, wire) = [ sender.class.name, wire.output, wire.target.is_a?(Proc) ? "block" : wire.target.class.name, wire.input ]
  end
end
