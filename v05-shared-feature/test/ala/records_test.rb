require "test_helper"

# Unit tests wire fakes to ports; nothing is stubbed by class name.
class RecordsTest < ActiveSupport::TestCase
  Recorder = Struct.new(:got) do
    include Foundation::Ports
    input(:input, ProgrammingParadigms::DataFlow) { |x| (self.got ||= []) << x }
  end

  def records = DomainAbstractions::Records.new(model: Product, project: ->(p) { p.name })

  test "load projects every record onto rows" do
    create_product(name: "A"); create_product(name: "B")
    r = records.wire_to(rows = Recorder.new, from: :rows)
    r.input_port(:load).send_event
    assert_equal [ %w[A B] ], rows.got
  end

  test "save sends a new record on created, an existing one on updated, and an invalid one back as the form" do
    r = records.wire_to(created = Recorder.new, from: :created).wire_to(updated = Recorder.new, from: :updated).wire_to(form = Recorder.new, from: :form)
    r.input_port(:save).push(id: nil, attrs: { name: "", amount: nil })
    assert_nil created.got
    assert form.got.first.errors[:name].any?

    r.input_port(:save).push(id: nil, attrs: { name: "Ok", amount: 5 })
    assert_equal "Ok", created.got.first.name
    r.input_port(:save).push(id: created.got.first.id, attrs: { name: "Renamed" })
    assert_equal "Renamed", updated.got.first.name
    assert_equal 1, created.got.size
  end

  test "an unwired optional output is inert" do
    create_product
    assert_nothing_raised { records.input_port(:load).send_event }
  end
end
