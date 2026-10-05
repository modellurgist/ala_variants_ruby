module DomainAbstractions
  # The logic abstractions a live dataflow diagram is drawn with (§2.9.3, the AND gate). Each keeps
  # the last value of every input and sends its output whenever that output changes.

  # An event passes through only while every level input is true.
  # In: fire (Event), a, b (DataFlow booleans). Out: passed (Event).
  class Gate
    include Foundation::Ports
    output :passed, ProgrammingParadigms::Event
    input(:a, ProgrammingParadigms::DataFlow) { |v| @a = v }
    input(:b, ProgrammingParadigms::DataFlow) { |v| @b = v }
    input(:fire, ProgrammingParadigms::Event) { emit(:passed) if @a && @b }
    def initialize = (@a, @b = false, false)
  end

  # In: in (DataFlow boolean). Out: out, its negation, whenever it changes.
  class Not
    include Foundation::Ports
    output :out, ProgrammingParadigms::DataFlow
    input(:in, ProgrammingParadigms::DataFlow) { |v| changed(!v) }

    private

    def changed(value)
      return if value == @last
      @last = value
      emit(:out, value)
    end
  end

  # Config: value. In: in (DataFlow). Out: out, whether the input equals the value, whenever that changes.
  class Equals
    include Foundation::Ports
    output :out, ProgrammingParadigms::DataFlow
    input(:in, ProgrammingParadigms::DataFlow) { |v| changed(v == @value) }
    def initialize(value) = @value = value

    private

    def changed(value)
      return if value == @last
      @last = value
      emit(:out, value)
    end
  end

  # In: in (DataFlow boolean). Out: rose (Event) on each change from false to true.
  class RisingEdge
    include Foundation::Ports
    output :rose, ProgrammingParadigms::Event
    input(:in, ProgrammingParadigms::DataFlow) do |v|
      emit(:rose) if v && @last == false
      @last = v
    end
    def initialize = @last = nil
  end
end
