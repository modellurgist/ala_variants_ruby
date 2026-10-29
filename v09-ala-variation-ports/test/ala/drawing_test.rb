require "test_helper"

# The drawing is read from the `wire` arms, so it must show every wire the screen makes, and a
# feature's arms inside it; a part the page calls is not drawn.
class DrawingTest < ActiveSupport::TestCase
  def cart = Screens::Cart.new(cart_id: Cart.create!(status: "open").id)

  test "the cart's chart has a node per part, a subgraph per feature, and an edge per arm" do
    chart = ProgrammingParadigms::Drawing.mermaid(cart)
    assert_includes chart, "flowchart LR"
    assert_includes chart, "subgraph order [order: OrderLines]"
    assert_includes chart, "order_lines[lines]"
    assert_includes chart, "order_lines -- removed --> order"
    assert_includes chart, "order -- undo_pending --> screen"
    assert_includes chart, "order -- changed --> items"
    assert_includes chart, "totals -- summary --> screen"
    assert_no_match(/order_undo|saved_store|wishlist_store/, chart)
  end

  test "the checkout's chart draws its wired parts and sinks, not the parts it calls" do
    chart = ProgrammingParadigms::Drawing.mermaid(Screens::Checkout.new(cart_id: Cart.create!(status: "open").id))
    assert_includes chart, "lines -- contents --> totals"
    assert_includes chart, "publish_stock[publish_stock]"
    assert_includes chart, "feed -- paid --> screen"
    assert_no_match(/\b(settle|charge|flow)\[/, chart)
  end
end
