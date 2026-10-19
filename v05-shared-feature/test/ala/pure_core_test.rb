require "test_helper"

# The state abstractions are values: wired to fakes on their ports, they run without a store.
class PureCoreTest < ActiveSupport::TestCase
  include DomainAbstractions

  Recorder = Struct.new(:got) do
    include Foundation::Ports
    input(:input, ProgrammingParadigms::DataFlow) { |x| (self.got ||= []) << x }
  end

  Answerer = Struct.new(:answer) do
    include Foundation::Ports
    input(:ask, ProgrammingParadigms::RequestResponse) { |q| answer.respond_to?(:call) ? answer.(q) : answer }
  end

  ROWS = { 7 => { id: 7, name: "Widget", amount: Foundation::Money[1000], stock: 3, stock_status: :low_stock, thumbnail: "w", description: "d" } }.freeze

  def lines
    lines = CartLines.new(cart_id: 1)
    lines.wire_to(Answerer.new([ { id: 42, product_id: 7, quantity: 2, gift_wrapped: false } ]), from: :items, to: :ask)
    lines.wire_to(Answerer.new(->(ids) { ROWS.slice(*ids) }), from: :products, to: :ask)
    lines.wire_to(@changed = Recorder.new, from: :changed).wire_to(@contents = Recorder.new, from: :contents)
    lines.input_port(:load).send_event
    lines
  end

  test "a change to a line it doesn't hold is refused by name" do
    error = assert_raises(ArgumentError) { lines.input_port(:bump).push(item_id: 99, delta: 1) }
    assert_equal "no line 99", error.message
  end

  test "a bump changes the value, announces the write, and prices what it holds" do
    l = lines.wire_to(row = Recorder.new, from: :row_changed)
    l.input_port(:bump).push(item_id: 42, delta: 1)
    assert_equal [ { op: :quantity, id: 42, quantity: 3 } ], @changed.got
    assert_equal 3, row.got.first[:quantity]
    assert_equal "$30.00", row.got.first[:line_total].to_s
    assert_equal [ { quantity: 3, amount: 1000 } ], @contents.got.last[:lines]
  end

  test "a removal forgets the line and tells undo, writing nothing itself" do
    l = lines.wire_to(removed = Recorder.new, from: :removed).wire_to(gone = Recorder.new, from: :row_removed)
    l.input_port(:remove).push(42)
    assert_equal [ 42 ], removed.got
    assert_equal 42, gone.got.first[:id]
    assert_nil @changed.got
    assert_equal [], @contents.got.last[:lines]
  end

  test "receiving a product asks the store to add it, and the stored line arrives as a row" do
    l = lines.wire_to(adding = Recorder.new, from: :adding).wire_to(added = Recorder.new, from: :row_added)
    l.input_port(:receive).push(7)
    assert_equal [ { product_id: 7, quantity: 1 } ], adding.got
    l.input_port(:arrived).push(id: 43, product_id: 7, quantity: 1, gift_wrapped: false)
    assert_equal 43, added.got.first[:id]
    assert_equal 2, @contents.got.last[:lines].size
  end
end
