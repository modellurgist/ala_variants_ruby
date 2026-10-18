require "test_helper"

# The feature is one part to a page: given its data and a products lambda it runs like a value, and
# what it returns is what leaves it; its two pages differ only in what they configure and wire.
class OrderLinesTest < ActiveSupport::TestCase
  ROWS = { 7 => { id: 7, name: "Widget", amount: Foundation::Money[1000], stock: 3, stock_status: :low_stock, thumbnail: "w", description: "d" } }.freeze

  def order(links: ->(id) { { remove: "/x/#{id}" } })
    cart = Cart.create!(status: "open")
    item = CartItem.add(cart.id, create_product.id)
    order = Features::OrderLines.new(cart_id: cart.id, products: ->(ids) { ROWS.slice(*ids) }, links:, undo_lines: CartItem, undo_window: 5.seconds)
    order.load([ { id: item.id, product_id: 7, quantity: 2, gift_wrapped: false } ])
    [ order, item ]
  end

  test "a removal is held for undo inside the feature and leaves as a row removed; undo brings it back" do
    o, item = order
    out = o.remove(item.id).to_h
    assert_equal item.id, out[:row_removed][:id]
    assert_equal true, out[:undo_pending]
    assert_nil out[:changed]
    assert_not_nil item.reload.removed_at
    out = o.undo.to_h
    assert_equal item.id, out[:restored]
    assert_equal false, out[:undo_pending]
    assert_nil item.reload.removed_at
  end

  test "a bump leaves as the write, the row and the contents" do
    o, item = order
    out = o.bump(item_id: item.id, delta: 1).to_h
    assert_equal({ op: :quantity, id: item.id, quantity: 3 }, out[:changed])
    assert_equal 3, out[:row_changed][:quantity]
    assert_equal [ { quantity: 3, amount: 1000 } ], out[:contents][:lines]
  end

  test "the same feature carries a page's own links" do
    o, item = order(links: ->(id) { { quantity: "/portal/lines/#{id}" } })
    assert_equal({ quantity: "/portal/lines/#{item.id}" }, o.load([ { id: item.id, product_id: 7, quantity: 2, gift_wrapped: false } ]).to_h[:rows].first[:urls])
  end
end
