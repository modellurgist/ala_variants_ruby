require "test_helper"

# The drawing is read from the `wire` arms, so it must show every wire the screen makes.
class DrawingTest < ActiveSupport::TestCase
  test "the cart's chart has a node per part and an edge per arm" do
    chart = ProgrammingParadigms::Drawing.mermaid(Screens::Cart)
    assert_includes chart, "flowchart LR"
    assert_includes chart, "  lines[lines]"
    assert_includes chart, "lines -- removed --> undo"
    assert_includes chart, "lines -- changed --> items"
    assert_includes chart, "saved -- changed --> saved_store"
    assert_includes chart, "saved -- changed --> saved"
    assert_includes chart, "totals -- summary --> screen"
  end

  test "the checkout's chart draws the sinks it runs" do
    chart = ProgrammingParadigms::Drawing.mermaid(Screens::Checkout)
    assert_includes chart, "settle -- stock_changed --> stock_update"
    assert_includes chart, "charge -- charged --> settle"
    assert_includes chart, "charge -- charged --> status"
    assert_includes chart, "flow -- ready_to_pay --> screen"
  end
end
