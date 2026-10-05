require "minitest/autorun"
require_relative "../lib/thermometer"

class ThermometerTest < Minitest::Test
  def thermometer(samples) = Thermometer.new(adc: Foundation::Adc.new(samples:))

  def test_the_display_shows_the_smoothed_scaled_reading_every_tenth_tick
    t = thermometer([ 400 ] * 10)
    10.times { t.input_port(:tick).send_event }
    t.input_port(:show).send_event
    assert_equal [ "Thermometer", "Temperature: 40.0 C" ], t.frame
  end

  def test_the_filter_moves_toward_a_new_reading
    t = thermometer([ 450 ] * 10)
    10.times { t.input_port(:tick).send_event }
    t.input_port(:show).send_event
    assert_match(/Temperature: 46\.5 C/, t.frame.last)
  end

  def test_nothing_shows_before_the_tenth_tick_and_an_exhausted_adc_is_quiet
    t = thermometer([ 400 ] * 3)
    5.times { t.input_port(:tick).send_event }
    t.input_port(:show).send_event
    assert_equal [ "Thermometer", "Temperature: waiting for a reading" ], t.frame
  end

  def test_every_output_is_wired_and_the_drawing_reads_as_the_diagram
    t = thermometer([])
    assert_empty t.parts.flat_map { |name, part| part.unwired_outputs.map { "#{name}.#{_1}" } }
    chart = ProgrammingParadigms::Drawing.mermaid(t)
    assert_includes chart, "reader -- reading → input --> scale"
    assert_includes chart, "sampler -- output → value --> display"
    assert_includes chart, "window -- contains → render --> display"
  end
end
