module DomainAbstractions
  # A front panel (§2.9.1): a push button that sends an event, and a lamp you can control. (Spray
  # notes these should have been two abstractions; they stay one here to match his diagram.)
  # In: sense (a SensorReading), light (DataFlow boolean). Out: button (Event, once per push),
  # indicator (DataFlow :on/:off).
  class UserInterface
    include Foundation::Ports
    output :button, ProgrammingParadigms::Event
    output :indicator, ProgrammingParadigms::DataFlow

    input(:sense, ProgrammingParadigms::DataFlow) { |reading| emit(:button) if reading.button == :pushed }
    input(:light, ProgrammingParadigms::DataFlow) { |on| emit(:indicator, on ? :on : :off) }
  end
end
