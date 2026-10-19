require "test_helper"

class CartUndosControllerTest < ActionDispatch::IntegrationTest
  test "undo restores the removed item, flashes, and recomputes totals" do
    item = add_to_cart(products(:widget))
    delete cart_item_path(item), headers: turbo_stream
    post cart_undo_path, headers: turbo_stream
    assert_nil item.reload.removed_at
    assert_turbo_stream action: "update", target: "undo_banner"
    assert_turbo_stream action: "append", target: "cart_items"
    assert_stream_text "flash", /Item restored/
    assert_turbo_stream action: "update", target: "cart_summary" do
      assert_select "dd", "$15.99"
    end
  end

  test "only the most recent removal is undoable" do
    first = add_to_cart(products(:widget))
    second = add_to_cart(products(:gadget))
    delete cart_item_path(first), headers: turbo_stream
    delete cart_item_path(second), headers: turbo_stream
    post cart_undo_path, headers: turbo_stream
    assert_equal [ second ], current_cart.items.to_a
    assert_not CartItem.exists?(first.id)
  end

  test "undo after the window has elapsed just clears the banner" do
    get cart_path
    post cart_undo_path, headers: turbo_stream
    assert_turbo_stream action: "update", target: "undo_banner"
    assert_no_turbo_stream action: "append"
  end
end
