require "test_helper"

class WishlistItemsControllerTest < ActionDispatch::IntegrationTest
  test "removing a product from the wishlist unmarks its cart row" do
    item = add_to_cart(products(:widget))
    wishlist_item = current_cart.toggle_wishlist(products(:widget))
    delete cart_wishlist_item_path(wishlist_item), headers: turbo_stream
    assert_turbo_stream action: "remove", target: "wishlist_item_#{wishlist_item.id}"
    assert_turbo_stream action: "replace", target: "cart_item_#{item.id}"
    assert_stream_text "flash", /Removed from wishlist/
    assert_empty current_cart.wishlist_items
  end

  test "removing a product that isn't in the cart" do
    get cart_path
    wishlist_item = current_cart.toggle_wishlist(products(:pallet))
    delete cart_wishlist_item_path(wishlist_item), headers: turbo_stream
    assert_turbo_stream action: "remove", target: "wishlist_item_#{wishlist_item.id}"
    assert_no_turbo_stream action: "replace"
  end

  test "add to cart from the wishlist persists a line, flashes, and drops it from the wishlist" do
    get cart_path
    wishlist_item = current_cart.toggle_wishlist(products(:pallet))
    post add_to_cart_cart_wishlist_item_path(wishlist_item), headers: turbo_stream
    line = current_cart.items.sole
    assert_equal products(:pallet), line.product
    assert_turbo_stream action: "remove", target: "wishlist_item_#{wishlist_item.id}"
    assert_turbo_stream action: "append", target: "cart_items"
    assert_stream_text "flash", /Added to cart/
    assert_stream_text "wishlist_count", "0"
    assert_empty current_cart.wishlist_items
  end
end
