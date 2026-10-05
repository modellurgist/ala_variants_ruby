require_relative "coffee_maker/foundation/ports"
require_relative "coffee_maker/foundation/hardware"
require_relative "coffee_maker/foundation/simulated_hardware"
require_relative "coffee_maker/programming_paradigms/data_flow"
require_relative "coffee_maker/programming_paradigms/event"
require_relative "coffee_maker/programming_paradigms/state_machine"
require_relative "coffee_maker/programming_paradigms/drawing"
require_relative "coffee_maker/domain_abstractions/logic"
require_relative "coffee_maker/domain_abstractions/boiler"
require_relative "coffee_maker/domain_abstractions/warmer_plate"
require_relative "coffee_maker/domain_abstractions/user_interface"

# Spray's coffee maker (§2.9.3) as wired instances: the only module where the word "coffee" appears.
# Each line of the constructor is a line of his diagram. A cycle pushes one SensorReading through the
# three hardware abstractions and answers with the HardwareCommand their outputs landed in.
class CoffeeMaker
  include Foundation::Ports
  include DomainAbstractions

  FLOW = [ [ :idle, :brew, :brewing ], [ :brewing, :dry, :brewed ], [ :brewed, :replaced, :idle ] ].freeze

  attr_reader :command

  def parts = { ui: @ui, boiler: @boiler, plate: @plate, state: @state, start: @start, boiler_has_water: @not_empty,
                pot_off: @pot_off, ran_dry: @ran_dry, pot_replaced: @pot_replaced, brewing: @brewing, brewed: @brewed }

  input(:cycle, ProgrammingParadigms::DataFlow) do |reading|
    [ @boiler, @plate, @ui ].each { _1.input_port(:sense).push(reading) }
    @command
  end

  def initialize
    @command = Foundation::HardwareCommand.off
    @ui, @boiler, @plate = UserInterface.new, Boiler.new, WarmerPlate.new
    @state = ProgrammingParadigms::StateMachine.new(transitions: FLOW, start: :idle)
    @start, @not_empty, @pot_off = Gate.new, Not.new, Not.new
    @ran_dry, @pot_replaced = RisingEdge.new, RisingEdge.new
    @brewing, @brewed = Equals.new(:brewing), Equals.new(:brewed)

    # pressing the button starts brewing, provided the boiler has water and the pot is on the plate
    @ui.wire_to(@start, from: :button, to: :fire)
    @boiler.wire_to(@not_empty, from: :empty, to: :in)
    @not_empty.wire_to(@start, from: :out, to: :a)
    @plate.wire_to(@start, from: :pot_on_plate, to: :b)
    @start.wire_to(@state, from: :passed, to: :brew)
    # while brewing, the boiler is on
    @state.wire_to(@brewing, from: :state, to: :in)
    @brewing.wire_to(@boiler, from: :out, to: :on)
    # the valve opens whenever the pot is off the plate
    @plate.wire_to(@pot_off, from: :pot_on_plate, to: :in)
    @pot_off.wire_to(@boiler, from: :out, to: :open_valve)
    # the boiler running dry means brewed, and brewed lights the lamp
    @boiler.wire_to(@ran_dry, from: :empty, to: :in)
    @ran_dry.wire_to(@state, from: :rose, to: :dry)
    @state.wire_to(@brewed, from: :state, to: :in)
    @brewed.wire_to(@ui, from: :out, to: :light)
    # an empty pot put back means idle again
    @plate.wire_to(@pot_replaced, from: :pot_empty, to: :in)
    @pot_replaced.wire_to(@state, from: :rose, to: :replaced)
    # the actuators
    @boiler.on(:heater) { @command = @command.with(boiler_heater: _1) }
    @boiler.on(:valve) { @command = @command.with(relief_valve: _1) }
    @plate.on(:heater) { @command = @command.with(warmer_heater: _1) }
    @ui.on(:indicator) { @command = @command.with(indicator: _1) }
  end
end
