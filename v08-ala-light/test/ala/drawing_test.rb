require "test_helper"

# The drawing is read from the `wire` arms, so it must show every wire the screen makes, and a
# feature's arms inside it.
class DrawingTest < ActiveSupport::TestCase
  def cart = Screens::Cart.new(cart_id: Cart.create!(status: "open").id)

  test "the cart's chart has a node per part, a subgraph per feature, and an edge per arm" do
    chart = ProgrammingParadigms::Drawing.mermaid(cart)
    assert_includes chart, "flowchart LR"
    assert_includes chart, "subgraph order [order: OrderLines]"
    assert_includes chart, "order_lines[lines]"
    assert_includes chart, "order_lines -- removed --> order_undo"
    assert_includes chart, "order_undo -- pending --> order"
    assert_includes chart, "order -- changed --> items"
    assert_includes chart, "saved -- changed --> saved_store"
    assert_includes chart, "totals -- summary --> screen"
  end

  test "the checkout's chart draws the sinks it runs" do
    chart = ProgrammingParadigms::Drawing.mermaid(Screens::Checkout.new(cart_id: Cart.create!(status: "open").id))
    assert_includes chart, "settle -- stock_changed --> publish_stock"
    assert_includes chart, "charge -- charged --> settle"
    assert_includes chart, "flow -- ready_to_pay --> screen"
  end
end
