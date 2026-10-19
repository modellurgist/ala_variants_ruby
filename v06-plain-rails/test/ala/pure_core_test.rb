require "test_helper"

# The state abstractions are values: given their data and a products lambda, they run without a store,
# and what they return is what they announce.
class PureCoreTest < ActiveSupport::TestCase
  include DomainAbstractions

  ROWS = { 7 => { id: 7, name: "Widget", amount: Foundation::Money[1000], stock: 3, stock_status: :low_stock, thumbnail: "w", description: "d" } }.freeze

  def lines
    lines = CartLines.new(cart_id: 1, rows: Rules::LineRow.new(products: ->(ids) { ROWS.slice(*ids) }))
    lines.load([ { id: 42, product_id: 7, quantity: 2, gift_wrapped: false } ])
    lines
  end

  test "a change to a line it doesn't hold is refused by name" do
    error = assert_raises(ArgumentError) { lines.bump(item_id: 99, delta: 1) }
    assert_equal "no line 99", error.message
  end

  test "a bump changes the value, announces the write, and prices what it holds" do
    out = lines.bump(item_id: 42, delta: 1)
    assert_equal({ op: :quantity, id: 42, quantity: 3 }, out[:changed])
    assert_equal 3, out[:row_changed][:quantity]
    assert_equal "$30.00", out[:row_changed][:line_total].to_s
    assert_equal [ { quantity: 3, amount: 1000 } ], out[:contents][:lines]
  end

  test "a removal forgets the line and tells undo, writing nothing itself" do
    out = lines.remove(42)
    assert_equal 42, out[:removed]
    assert_equal 42, out[:row_removed][:id]
    assert_nil out[:changed]
    assert_equal [], out[:contents][:lines]
  end

  test "receiving a product asks the store to add it, and the stored line arrives as a row" do
    l = lines
    assert_equal({ adding: { product_id: 7, quantity: 1 } }, l.receive(7))
    out = l.arrived(id: 43, product_id: 7, quantity: 1, gift_wrapped: false)
    assert_equal 43, out[:row_added][:id]
    assert_equal 2, out[:contents][:lines].size
  end
end
