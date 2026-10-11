require "application_system_test_case"

class CartSystemTest < ApplicationSystemTestCase
  setup { @product = create_product(name: "Widget", amount: 1000) }

  def add_to_cart
    visit products_path
    click_on "Add to cart"
    assert_text "Added to cart"
  end

  test "tabs switch panes and a shipping choice submits itself" do
    add_to_cart
    visit cart_path
    assert_selector "[data-name=items]:not([hidden])", text: "Widget"
    click_on "Saved (0)"
    assert_selector "[data-name=saved]:not([hidden])", text: "No saved items."
    choose "Express (2–3 days)"
    assert_text "Shipping (Express (2–3 days))"
    assert_text "$22.99"
  end

  test "a removal offers undo, then expires on its own" do
    add_to_cart
    visit cart_path
    click_on "Remove"
    assert_text "Item removed."
    assert_button "Undo"
    assert_no_text "Item removed.", wait: 8
    assert_text "Your cart is empty."
  end
end
