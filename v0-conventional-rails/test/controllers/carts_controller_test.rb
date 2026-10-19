require "test_helper"

class CartsControllerTest < ActionDispatch::IntegrationTest
  test "the first visit creates an open cart and keeps it in the session" do
    assert_difference("Cart.count") { get cart_path }
    cart = current_cart
    assert cart.open?
    assert_no_difference("Cart.count") { get cart_path }
    assert_equal cart, current_cart
  end

  test "a completed cart is replaced by a new empty one" do
    get cart_path
    old = current_cart
    old.completed!
    get cart_path
    assert_not_equal old, current_cart
    assert current_cart.open?
  end

  test "the storefront cart and the portal draft are separate carts under separate keys" do
    get cart_path
    get portal_path
    assert_not_equal session[:cart_id], session[:portal_cart_id]
    assert Cart.find(session[:cart_id]).storefront?
    assert Cart.find(session[:portal_cart_id]).portal?
  end

  test "cart contents persist across page loads" do
    add_to_cart(products(:widget))
    add_to_cart(products(:widget))
    get cart_path
    get cart_path
    assert_select "#cart_items [data-testid=quantity]", "2"
  end

  test "shows each item with name, thumbnail, unit price, quantity, line total, stock status, and gift wrap" do
    item = add_to_cart(products(:widget))
    item.update!(quantity: 2, gift_wrap: true)
    add_to_cart(products(:gadget))
    get cart_path
    assert_select "#cart_item_#{item.id}" do
      assert_select "p", /Widget/
      assert_select "img[src=?]", products(:widget).thumbnail
      assert_select "p", /\$10.00 each/
      assert_select "[data-testid=quantity]", "2"
      assert_select "span", "$20.00"
      assert_select "span", "In stock"
      assert_select "p", "Gift-wrapped"
    end
    assert_select "span", "Low stock (3 left)"
  end

  test "an empty cart says so and disables checkout" do
    get cart_path
    assert_select "#cart_summary p", "Your cart is empty."
    assert_select "#cart_summary button[disabled]", "Checkout"
  end

  test "tabs show their counts: total quantity, saved, wishlist" do
    add_to_cart(products(:widget)).update!(quantity: 3)
    add_to_cart(products(:gadget)).save_for_later!
    current_cart.toggle_wishlist(products(:pallet))
    get cart_path
    assert_select "[role=tab]", 3
    assert_select "#items_count", "3"
    assert_select "#saved_count", "1"
    assert_select "#wishlist_count", "1"
    assert_select "#saved_items", /Gadget/
    assert_select "#wishlist_items", /Pallet/
  end

  test "the summary shows discount, gift wrap, shipping label, and total" do
    add_to_cart(products(:widget)).update!(gift_wrap: true)
    current_cart.apply_promo_code("SAVE10")
    get cart_path
    assert_select "#cart_summary" do
      assert_select "dt", "Discount (SAVE10)"
      assert_select "dd", "−$1.00"
      assert_select "dt", "Gift wrap"
      assert_select "dt", "Shipping (Standard (5–7 days))"
      assert_select "dd", "$5.99"
      assert_select "dd", "$17.98"
    end
  end

  test "a pending removal still offers undo after a reload" do
    add_to_cart(products(:widget)).remove!
    get cart_path
    assert_select "#undo_banner", /Item removed/
    assert_select "#undo_banner button", "Undo"
  end

  test "the success page thanks the shopper and shows the order" do
    add_to_cart(products(:widget))
    order = current_cart.place_order
    get success_cart_path
    assert_select "h1", "Thank you for your order!"
    assert_select "strong", order.reference
  end

  test "the success page still thanks the shopper when there is no order to show" do
    get success_cart_path
    assert_select "h1", "Thank you for your order!"
    assert_select "strong", count: 0
  end
end
