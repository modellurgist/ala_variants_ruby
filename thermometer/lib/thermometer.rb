require_relative "thermometer/foundation/ports"
require_relative "thermometer/foundation/adc"
require_relative "thermometer/programming_paradigms/data_flow"
require_relative "thermometer/programming_paradigms/event"
require_relative "thermometer/programming_paradigms/ui_layout"
require_relative "thermometer/programming_paradigms/drawing"
require_relative "thermometer/domain_abstractions/pipeline"

# Spray's thermometer at §1.6.6: instances configured with the application's numbers and words, a
# dataflow chain from the ADC to a display, the display inside a window, and a tick that drives it.
# Every literal is here; every line of the constructor is a line of the diagram.
class Thermometer
  include Foundation::Ports
  include DomainAbstractions

  attr_reader :frame

  def parts = { reader: @reader, scale: @scale, filter: @filter, sampler: @sampler, display: @display, window: @window }

  input(:tick, ProgrammingParadigms::Event) { @reader.input_port(:tick).send_event }
  input(:show, ProgrammingParadigms::Event) { @window.input_port(:show).send_event }

  def initialize(adc:)
    @reader = Reader.new(source: adc)
    @scale = OffsetAndScale.new(offset: -200, scale: 0.2)
    @filter = LowPassFilter.new(strength: 10, initial: 40.0)
    @sampler = SampleEvery.new(n: 10)
    @display = Display.new(label: "Temperature", units: "C", format: "%<label>s: %<value>.1f %<units>s", empty: "Temperature: waiting for a reading")
    @window = Window.new(title: "Thermometer")

    @reader.wire_in(@scale).wire_in(@filter).wire_in(@sampler).wire_in(@display)
    @window.wire_to(@display, from: :contains, to: :render)
    @window.on(:frame) { @frame = _1 }
  end
end
