require "test_helper"

# The feature is one part to a page: wired to fakes on its ports it runs without a store, and its
# two pages differ only in what they wire and configure.
class OrderLinesTest < ActiveSupport::TestCase
  Recorder = Struct.new(:got) do
    include Foundation::Ports
    input(:input, ProgrammingParadigms::DataFlow) { |x| (self.got ||= []) << x }
  end

  Answerer = Struct.new(:answer) do
    include Foundation::Ports
    input(:ask, ProgrammingParadigms::RequestResponse) { |q| answer.respond_to?(:call) ? answer.(q) : answer }
  end

  ROWS = { 7 => { id: 7, name: "Widget", amount: Foundation::Money[1000], stock: 3, stock_status: :low_stock, thumbnail: "w", description: "d" } }.freeze

  def order(links: ->(id) { { remove: "/x/#{id}" } })
    cart = Cart.create!(status: "open")
    item = CartItem.add(cart.id, create_product.id)
    order = Features::OrderLines.new(cart_id: cart.id, links:, undo_lines: CartItem, undo_window: 5.seconds)
    order.wire_to(Answerer.new([ { id: item.id, product_id: 7, quantity: 2, gift_wrapped: false } ]), from: :items, to: :ask)
    order.wire_to(Answerer.new(->(ids) { ROWS.slice(*ids) }), from: :products, to: :ask)
    order.wire_to(@changed = Recorder.new, from: :changed).wire_to(@contents = Recorder.new, from: :contents)
    order.wire_to(@pending = Recorder.new, from: :undo_pending).wire_to(@fetch = Recorder.new, from: :fetch)
    order.input_port(:load).send_event
    [ order, item ]
  end

  test "a removal is held for undo inside the feature; undo asks the page's store for the line back" do
    o, item = order
    o.wire_to(gone = Recorder.new, from: :row_removed)
    o.input_port(:remove).push(item.id)
    assert_equal [ item.id ], gone.got.map { _1[:id] }
    assert_equal [ false, true ], @pending.got
    assert_not_nil item.reload.removed_at
    assert_nil @changed.got
    o.input_port(:undo).send_event
    assert_equal [ item.id ], @fetch.got
    assert_nil item.reload.removed_at
    assert_equal false, @pending.got.last
  end

  test "the same feature carries a page's own links" do
    o, item = order(links: ->(id) { { quantity: "/portal/lines/#{id}" } })
    o.wire_to(rows = Recorder.new, from: :rows)
    o.input_port(:show).send_event
    assert_equal({ quantity: "/portal/lines/#{item.id}" }, rows.got.last.first[:urls])
  end

  test "a request for the lines passes through to the value" do
    o, item = order
    assert_equal [ item.id ], o.input_port(:lines).request(nil)[:lines].map { _1[:id] }
  end
end
