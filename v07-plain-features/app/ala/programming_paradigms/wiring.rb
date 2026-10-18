module ProgrammingParadigms
  # Wiring for a composition written as plain Ruby (§2.3.4, §3.11.3). A part's input is a public
  # method; its outputs are the pairs the method returns (a Hash of name => payload, or an Array of
  # [name, payload] when a name repeats); the composition's `wire(part, output, payload)` is one
  # `case` whose arms are the wires. `run(part, outputs)` feeds what a part returned through them, and
  # records, when a test run has the trace on, which output reached which part and which landed on
  # the composition itself. An output the composition lists in GROUNDED is dropped; any other output
  # without an arm is an error, which is the coverage test at run time.
  #
  # A feature (§2.2) is a composition that is itself a part of another: its inputs wrap their runs in
  # `collect`, and an arm that says `out(name, payload)` makes that pair one of the feature's own
  # outputs, returned to whoever ran it.
  module Wiring
    private

    def run(part, outputs)
      reached(part)
      outputs&.each do |output, payload|
        next if self.class::GROUNDED.include?(:"#{part}.#{output}")
        routing([ part, output ]) { wire(part, output, payload) }
      end
      nil
    end

    def collect
      saved, @out = @out, []
      yield
      @out
    ensure
      @out = saved
    end

    def out(output, payload) = (@out << [ output, payload ]; nil)

    def reached(part)
      return unless Foundation::Trace.enabled?
      Foundation::Trace.hop(self.class, @routing || :outside, part)
      @reached = true
    end

    def routing(from)
      saved = [ @routing, @reached ]
      @routing, @reached = from, false
      yield
      Foundation::Trace.hop(self.class, from, :screen) if Foundation::Trace.enabled? && !@reached
    ensure
      @routing, @reached = saved
    end
  end
end
