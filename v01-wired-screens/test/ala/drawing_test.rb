require "test_helper"

# The drawing is read from the built object graph, so it must show every wire the screen makes.
class DrawingTest < ActiveSupport::TestCase
  test "the cart's chart has a node per part and an edge per wire" do
    cart = Cart.create!(status: "open")
    chart = ProgrammingParadigms::Drawing.mermaid(Screens::Cart.new(cart_id: cart.id))
    assert_includes chart, "flowchart LR"
    assert_includes chart, "lines[lines: CartLines]"
    assert_includes chart, "lines -- removed → capture --> undo"
    assert_includes chart, "totals -- summary --> screen"
  end

  test "the checkout's chart draws the inline sink and the job's port" do
    cart = Cart.create!(status: "open")
    chart = ProgrammingParadigms::Drawing.mermaid(Screens::Checkout.new(cart_id: cart.id))
    assert_match(/settle -- stock_changed → push --> \w+\(\[LiveUpdate\]\)/, chart)
    assert_match(/flow -- ready_to_pay --> \w+\(\[DataFlow port\]\)/, chart)
  end
end
