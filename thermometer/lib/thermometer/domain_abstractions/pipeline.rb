module DomainAbstractions
  # The dataflow abstractions of Spray's thermometer (§1.6.5), each a stage with one DataFlow in and
  # one out, configured once, knowing nothing of thermometers.

  # Reads a source on each event and sends what it read. Config: source (answers `read`, nil when
  # exhausted). In: tick (Event). Out: reading (DataFlow).
  class Reader
    include Foundation::Ports
    output :reading, ProgrammingParadigms::DataFlow
    input(:tick, ProgrammingParadigms::Event) do
      value = @source.read
      emit(:reading, value) unless value.nil?
    end
    def initialize(source:) = @source = source
  end

  # Config: offset, scale. In: input. Out: output, (input + offset) * scale.
  class OffsetAndScale
    include Foundation::Ports
    output :output, ProgrammingParadigms::DataFlow
    input(:input, ProgrammingParadigms::DataFlow) { |v| emit(:output, (v + @offset) * @scale) }
    def initialize(offset:, scale:) = (@offset, @scale = offset, scale)
  end

  # Smooths a stream, keeping its running value as its own state (R4). Config: strength, initial.
  # In: input. Out: output, the smoothed value, on every input.
  class LowPassFilter
    include Foundation::Ports
    output :output, ProgrammingParadigms::DataFlow
    input(:input, ProgrammingParadigms::DataFlow) do |v|
      @last += (v - @last) / @strength
      emit(:output, @last)
    end
    def initialize(strength:, initial:) = (@strength, @last = strength, initial)
  end

  # Passes every n-th value and swallows the rest: the guard in the connection, not the application
  # (§1.6.4). Config: n. In: input. Out: output.
  class SampleEvery
    include Foundation::Ports
    output :output, ProgrammingParadigms::DataFlow
    input(:input, ProgrammingParadigms::DataFlow) do |v|
      @count += 1
      emit(:output, v) if (@count % @n).zero?
    end
    def initialize(n:) = (@n, @count = n, 0)
  end

  # A UI element that shows the last value it was sent with a label and units, or the `empty` text
  # before any arrives. Config: label, units, format, empty. In: value (DataFlow). UI port: render,
  # by the window that contains it.
  class Display
    include Foundation::Ports
    input(:value, ProgrammingParadigms::DataFlow) { |v| @value = v }
    input(:render, ProgrammingParadigms::UiLayout) { [ @value.nil? ? @empty : format(@format, label: @label, value: @value, units: @units) ] }
    def initialize(label:, units:, format:, empty:) = (@label, @units, @format, @empty, @value = label, units, format, empty, nil)
  end

  # A window containing UI elements, top to bottom. Config: title. Out: contains (UiLayout, many).
  # In: show (Event), which sends the rendered frame on `frame`. Out: frame (DataFlow of lines).
  class Window
    include Foundation::Ports
    output :contains, ProgrammingParadigms::UiLayout, many: true
    output :frame, ProgrammingParadigms::DataFlow
    input(:show, ProgrammingParadigms::Event) { emit(:frame, [ @title ] + contents) }
    def initialize(title:) = @title = title
    private def contents = Array(@contains).flat_map(&:render)
  end
end
