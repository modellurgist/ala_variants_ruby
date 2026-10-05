module Foundation
  # A model of the physical world for running the machine without one: water that boils away while
  # the heater is on, a pot that fills as it does, a button that stays pushed for one reading.
  # Config: water (units in the boiler). In: a HardwareCommand per cycle. Out: a SensorReading.
  class SimulatedHardware
    attr_reader :water, :pot_contents, :pot_on_plate, :last_command

    def initialize(water:)
      @water, @pot_contents, @pot_on_plate, @pushed = water, 0, true, false
      @last_command = HardwareCommand.off
    end

    def press_button = @pushed = true
    def lift_pot = @pot_on_plate = false
    def replace_pot(emptied: true) = (@pot_on_plate = true; @pot_contents = 0 if emptied)

    def reading
      plate = !@pot_on_plate ? :warmer_empty : @pot_contents.zero? ? :pot_empty : :pot_not_empty
      SensorReading.new(button: @pushed ? :pushed : :not_pushed, boiler: @water.zero? ? :empty : :not_empty, warmer_plate: plate)
    end

    # Applies a cycle's command: the button is consumed, and a heating boiler with its valve closed
    # moves one unit of water into the pot.
    def apply(command)
      @last_command = command
      @pushed = false
      return unless command.boiler_heater == :on && command.relief_valve == :closed && @water.positive?
      @water -= 1
      @pot_contents += 1 if @pot_on_plate
    end
  end
end
