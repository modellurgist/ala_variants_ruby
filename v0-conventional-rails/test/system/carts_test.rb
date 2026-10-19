require "application_system_test_case"

class CartsTest < ApplicationSystemTestCase
  setup { @widget = products(:widget) }

  test "steppers change the quantity and totals; the decrement is disabled at 1" do
    add_to_cart(@widget)
    visit cart_path
    assert_button "Decrease quantity", disabled: true
    click_on "Increase quantity"
    within("#cart_items") { assert_selector "[data-testid=quantity]", text: "2" }
    assert_text "Items (2)"
    within("#cart_summary") { assert_text "$25.99" }
    click_on "Decrease quantity"
    within("#cart_items") { assert_selector "[data-testid=quantity]", text: "1" }
    assert_button "Decrease quantity", disabled: true
  end

  test "tabs switch in the browser; save for later and move back" do
    add_to_cart(@widget)
    visit cart_path
    click_on "Save for later"
    assert_text "Saved for later"
    assert_text "Saved (1)"
    within("#cart_summary") { assert_text "Your cart is empty." }
    click_on "Saved (1)"
    within("#saved_items") { click_on "Move to cart" }
    assert_text "Moved to cart"
    click_on "Items (1)"
    within("#cart_items") { assert_text "Widget" }
  end

  test "wishlist from a row, then add to cart from the Wishlist tab" do
    add_to_cart(@widget)
    visit cart_path
    click_on "Add to wishlist"
    assert_text "Added to wishlist"
    within("#cart_items") { assert_text "♥ In wishlist" }
    click_on "Remove"
    assert_text "Item removed"
    click_on "Wishlist (1)"
    within("#wishlist_items") { click_on "Add to cart" }
    assert_text "Added to cart"
    assert_text "Wishlist (0)"
    click_on "Items (1)"
    within("#cart_items") { assert_text "Widget" }
  end

  test "promo codes and shipping choices reprice the summary" do
    add_to_cart(@widget)
    visit cart_path
    fill_in "Promo code", with: "bogus"
    click_on "Apply"
    within("#promo_form") { assert_text "Invalid promo code" }
    fill_in "Promo code", with: "HALF"
    click_on "Apply"
    assert_text "Promo applied!"
    within("#promo_form") { assert_no_text "Invalid promo code" }
    choose "shipping_method_express"
    within("#cart_summary") do
      assert_text "Discount (HALF)"
      assert_text "Shipping (Express (2–3 days))"
      assert_text "$17.99"
    end
  end

  test "remove offers undo, and undo restores the item" do
    add_to_cart(@widget)
    visit cart_path
    click_on "Remove"
    within("#undo_banner") { click_on "Undo" }
    assert_text "Item restored"
    assert_no_selector "#undo_banner button"
    within("#cart_items") { assert_text "Widget" }
    within("#cart_summary") { assert_text "$15.99" }
  end

  test "when the undo window elapses the removal is final and the banner goes" do
    add_to_cart(@widget)
    visit cart_path
    wait_for_streams
    click_on "Remove"
    within("#undo_banner") { assert_text "Item removed" }
    perform_enqueued_jobs(only: FinalizeRemovalJob)
    assert_no_text "Item removed"
    assert_empty CartItem.all
  end

  test "a stock change elsewhere updates the cart row live" do
    add_to_cart(products(:gadget))
    visit cart_path
    wait_for_streams
    within("#cart_items") { assert_text "Low stock (3 left)" }
    products(:gadget).update!(stock: 0)
    within("#cart_items") { assert_text "Out of stock" }
  end
end
