require "test_helper"

class CartItemsControllerTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  test "add to cart persists a line and flashes" do
    post cart_items_path, params: { product_id: products(:widget).id }, headers: { "HTTP_REFERER" => products_url }
    assert_redirected_to products_url
    assert_equal "Added to cart", flash[:notice]
    assert_equal 1, current_cart.items.sole.quantity
  end

  test "add to cart from the list flashes in place" do
    post cart_items_path, params: { product_id: products(:widget).id }, headers: turbo_stream
    assert_stream_text "flash", /Added to cart/
    assert_equal 1, current_cart.items.sole.quantity
  end

  test "adding the same product again increments its line" do
    add_to_cart(products(:widget))
    item = add_to_cart(products(:widget))
    assert_equal 2, item.quantity
    assert_equal 1, current_cart.items.count
  end

  test "steppers change the quantity, reprice, and persist" do
    item = add_to_cart(products(:widget))
    patch cart_item_path(item), params: { quantity: 2 }, headers: turbo_stream
    assert_equal 2, item.reload.quantity
    assert_turbo_stream action: "replace", target: "cart_item_#{item.id}" do
      assert_select "button[disabled]", count: 0
    end
    assert_stream_text "items_count", "2"
    assert_turbo_stream action: "update", target: "cart_summary" do
      assert_select "dd", "$25.99"
    end
  end

  test "the decrement is disabled at 1 and quantity never drops below 1" do
    item = add_to_cart(products(:widget))
    get cart_path
    assert_select "button[disabled][aria-label='Decrease quantity']"
    patch cart_item_path(item), params: { quantity: 0 }, headers: turbo_stream
    assert_equal 1, item.reload.quantity
  end

  test "removing an item drops the row, recomputes totals, and shows the undo banner" do
    item = add_to_cart(products(:widget))
    assert_enqueued_with(job: FinalizeRemovalJob) do
      delete cart_item_path(item), headers: turbo_stream
    end
    assert_turbo_stream action: "remove", target: "cart_item_#{item.id}"
    assert_turbo_stream action: "update", target: "undo_banner" do
      assert_select "span", "Item removed"
      assert_select "button", "Undo"
    end
    assert_turbo_stream action: "update", target: "cart_summary" do
      assert_select "p", "Your cart is empty."
    end
  end

  test "gift wrap toggles on and off and adds to the summary" do
    item = add_to_cart(products(:widget))
    patch gift_wrap_cart_item_path(item), headers: turbo_stream
    assert item.reload.gift_wrap
    assert_turbo_stream action: "update", target: "cart_summary" do
      assert_select "dt", "Gift wrap"
      assert_select "dd", "$2.99"
    end
    patch gift_wrap_cart_item_path(item), headers: turbo_stream
    assert_not item.reload.gift_wrap
    assert_turbo_stream action: "update", target: "cart_summary" do
      assert_select "dt", text: "Gift wrap", count: 0
    end
  end

  test "save for later moves the item to the Saved tab; move to cart brings it back" do
    item = add_to_cart(products(:widget))
    patch save_for_later_cart_item_path(item), headers: turbo_stream
    assert_turbo_stream action: "remove", target: "cart_item_#{item.id}"
    assert_turbo_stream action: "append", target: "saved_items"
    assert_stream_text "saved_count", "1"
    assert_stream_text "flash", /Saved for later/

    patch save_for_later_cart_item_path(item), headers: turbo_stream
    assert_equal 1, current_cart.saved_items.count

    patch move_to_cart_cart_item_path(item), headers: turbo_stream
    assert_turbo_stream action: "remove", target: "saved_cart_item_#{item.id}"
    assert_turbo_stream action: "append", target: "cart_items"
    assert_stream_text "flash", /Moved to cart/
    assert_equal [ item ], current_cart.items.to_a
  end

  test "wishlist toggles the product and marks the row" do
    item = add_to_cart(products(:widget))
    patch wishlist_cart_item_path(item), headers: turbo_stream
    assert_stream_text "flash", /Added to wishlist/
    assert_turbo_stream action: "append", target: "wishlist_items"
    assert_turbo_stream action: "replace", target: "cart_item_#{item.id}" do
      assert_select "span", "♥ In wishlist"
    end
    wishlist_item = current_cart.wishlist_items.sole

    patch wishlist_cart_item_path(item), headers: turbo_stream
    assert_stream_text "flash", /Removed from wishlist/
    assert_turbo_stream action: "remove", target: "wishlist_item_#{wishlist_item.id}"
    assert_empty current_cart.wishlist_items
  end

  test "items of another cart are not found" do
    other = Cart.create!.add_product(products(:widget))
    get cart_path
    patch cart_item_path(other), params: { quantity: 3 }, headers: turbo_stream
    assert_response :not_found
  end
end
