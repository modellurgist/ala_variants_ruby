require "minitest/autorun"
require_relative "../lib/coffee_maker"

# Martin's acceptance scenarios, each as readings in and commands out: the boundary is data, so no
# device is mocked.
class CoffeeMakerTest < Minitest::Test
  def setup = @maker = CoffeeMaker.new

  def cycle(button: :not_pushed, boiler: :not_empty, warmer_plate: :pot_empty)
    @maker.input_port(:cycle).push(Foundation::SensorReading.new(button:, boiler:, warmer_plate:))
    @maker.command
  end

  def test_idle_until_the_button_is_pressed
    assert_equal Foundation::HardwareCommand.off, cycle
  end

  def test_pressing_the_button_with_water_and_a_pot_starts_brewing
    cycle
    assert_equal :on, cycle(button: :pushed).boiler_heater
    assert_equal :on, cycle.boiler_heater
  end

  def test_no_brew_without_water_or_without_a_pot
    cycle(boiler: :empty)
    assert_equal :off, cycle(button: :pushed, boiler: :empty).boiler_heater
    cycle(warmer_plate: :warmer_empty)
    assert_equal :off, cycle(button: :pushed, warmer_plate: :warmer_empty).boiler_heater
  end

  def test_lifting_the_pot_opens_the_valve_and_the_boiler_stops_heating
    cycle
    cycle(button: :pushed)
    command = cycle(warmer_plate: :warmer_empty)
    assert_equal :open, command.relief_valve
    assert_equal :off, command.boiler_heater
    assert_equal :closed, cycle(warmer_plate: :pot_not_empty).relief_valve
    assert_equal :on, @maker.command.boiler_heater
  end

  def test_the_warmer_heats_only_a_pot_with_coffee_in_it
    assert_equal :off, cycle(warmer_plate: :pot_empty).warmer_heater
    assert_equal :on, cycle(warmer_plate: :pot_not_empty).warmer_heater
    assert_equal :off, cycle(warmer_plate: :warmer_empty).warmer_heater
  end

  def test_running_dry_means_brewed_and_lights_the_lamp
    cycle
    cycle(button: :pushed)
    command = cycle(boiler: :empty, warmer_plate: :pot_not_empty)
    assert_equal :on, command.indicator
    assert_equal :off, command.boiler_heater
    assert_equal :brewed, @maker.parts[:state].current
  end

  def test_replacing_the_emptied_pot_returns_to_idle
    cycle
    cycle(button: :pushed)
    cycle(boiler: :empty, warmer_plate: :pot_not_empty)
    cycle(boiler: :empty, warmer_plate: :warmer_empty)
    command = cycle(boiler: :empty, warmer_plate: :pot_empty)
    assert_equal :off, command.indicator
    assert_equal :idle, @maker.parts[:state].current
  end

  def test_a_fresh_button_press_while_brewed_does_nothing_until_the_pot_is_replaced
    cycle
    cycle(button: :pushed)
    cycle(boiler: :empty, warmer_plate: :pot_not_empty)
    assert_equal :brewed, @maker.parts[:state].current
    cycle(button: :pushed, boiler: :not_empty, warmer_plate: :pot_not_empty)
    assert_equal :brewed, @maker.parts[:state].current
  end

  def test_the_simulator_brews_a_pot_end_to_end
    world = Foundation::SimulatedHardware.new(water: 2)
    world.press_button
    log = 6.times.map do
      command = @maker.input_port(:cycle).push(world.reading)
      world.apply(command)
      [ @maker.parts[:state].current, command.boiler_heater, command.indicator ]
    end
    assert_equal [ :brewing, :on, :off ], log[0]
    assert_includes log, [ :brewed, :off, :on ]
    assert_equal 0, world.water
    assert_equal 2, world.pot_contents
  end
end

class WiringTest < Minitest::Test
  def test_every_output_of_every_part_is_wired
    maker = CoffeeMaker.new
    unwired = maker.parts.flat_map { |name, part| part.unwired_outputs.map { "#{name}.#{_1}" } }
    assert_empty unwired
    assert_empty maker.unwired_outputs
  end

  def test_the_drawing_has_a_line_per_wire
    chart = ProgrammingParadigms::Drawing.mermaid(CoffeeMaker.new)
    assert_includes chart, "ui -- button → fire --> start"
    assert_includes chart, "start -- passed → brew --> state"
    assert_includes chart, "ran_dry -- rose → dry --> state"
    assert_includes chart, "brewed -- out → light --> ui"
  end
end
