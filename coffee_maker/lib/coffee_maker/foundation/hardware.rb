module Foundation
  # The hardware boundary as data: every sensor read once per cycle into one value, every actuator
  # written once from one value. Nothing above these touches a device, so the same machine runs
  # against real hardware, the simulator, or a test.
  SensorReading = Data.define(:button, :boiler, :warmer_plate) do
    # button: :pushed | :not_pushed; boiler: :empty | :not_empty;
    # warmer_plate: :warmer_empty | :pot_empty | :pot_not_empty
    def self.idle = new(button: :not_pushed, boiler: :not_empty, warmer_plate: :pot_empty)
  end

  HardwareCommand = Data.define(:boiler_heater, :warmer_heater, :relief_valve, :indicator) do
    def self.off = new(boiler_heater: :off, warmer_heater: :off, relief_valve: :closed, indicator: :off)
  end
end
