module DomainAbstractions
  # A boiler (§2.9.1): it can be turned on or off, tells you when it is empty, and its steam release
  # valve stops the flow. It turns its own heater off when it runs dry or the valve is open; that rule
  # is the boiler's, never the application's.
  # In: sense (a SensorReading), on (DataFlow boolean), open_valve (DataFlow boolean).
  # Out: empty (DataFlow boolean, whenever it changes), heater (DataFlow :on/:off), valve (DataFlow :open/:closed).
  class Boiler
    include Foundation::Ports
    output :empty, ProgrammingParadigms::DataFlow, many: true
    output :heater, ProgrammingParadigms::DataFlow
    output :valve, ProgrammingParadigms::DataFlow

    input(:sense, ProgrammingParadigms::DataFlow) do |reading|
      dry = reading.boiler == :empty
      was, @dry = @dry, dry
      emit(:empty, dry) unless dry == was
      drive
    end
    input(:on, ProgrammingParadigms::DataFlow) { |v| @on = v; drive }
    input(:open_valve, ProgrammingParadigms::DataFlow) { |v| @open = v; drive }

    def initialize = (@on, @open, @dry = false, false, nil)

    private

    def drive
      emit(:valve, @open ? :open : :closed)
      emit(:heater, @on && !@dry && !@open ? :on : :off)
    end
  end
end
