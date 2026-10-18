require "test_helper"

# Unit tests call the abstraction and read what it returns; nothing is stubbed by class name.
class RecordsTest < ActiveSupport::TestCase
  def records = DomainAbstractions::Records.new(model: Product, project: ->(p) { p.name })

  test "load projects every record onto rows" do
    create_product(name: "A"); create_product(name: "B")
    assert_equal({ rows: %w[A B] }, records.load)
  end

  test "save returns a new record as created, an existing one as updated, and an invalid one as the form" do
    r = records
    out = r.save(id: nil, attrs: { name: "", amount: nil })
    assert_nil out[:created]
    assert out[:form].errors[:name].any?

    created = r.save(id: nil, attrs: { name: "Ok", amount: 5 })[:created]
    assert_equal "Ok", created.name
    assert_equal "Renamed", r.save(id: created.id, attrs: { name: "Renamed" })[:updated].name
  end
end
