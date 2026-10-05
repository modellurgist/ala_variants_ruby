module DomainAbstractions
  # A warmer plate (§2.9.1): it tells you whether a pot is on it and whether an empty pot is on it, and
  # it controls its own heater, on only under a pot with something in it.
  # In: sense (a SensorReading). Out: pot_on_plate, pot_empty (DataFlow booleans, whenever they
  # change), heater (DataFlow :on/:off).
  class WarmerPlate
    include Foundation::Ports
    output :pot_on_plate, ProgrammingParadigms::DataFlow, many: true
    output :pot_empty, ProgrammingParadigms::DataFlow
    output :heater, ProgrammingParadigms::DataFlow

    input(:sense, ProgrammingParadigms::DataFlow) do |reading|
      on_plate = reading.warmer_plate != :warmer_empty
      empty = reading.warmer_plate == :pot_empty
      emit(:pot_on_plate, on_plate) unless on_plate == @on_plate
      emit(:pot_empty, empty) unless empty == @empty
      @on_plate, @empty = on_plate, empty
      emit(:heater, on_plate && !empty ? :on : :off)
    end

    def initialize = (@on_plate, @empty = nil, nil)
  end
end
