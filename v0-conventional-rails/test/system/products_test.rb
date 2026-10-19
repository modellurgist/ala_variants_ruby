require "application_system_test_case"

class ProductsTest < ApplicationSystemTestCase
  test "creating a product in the modal validates live and adds it to the list" do
    visit products_path
    click_on "New Product"
    within "turbo-frame#modal" do
      fill_in "Amount (cents)", with: "750"
      assert_text "Name can't be blank"
      fill_in "Name", with: "Gizmo"
      assert_no_text "Name can't be blank"
      click_on "Save Product"
    end
    assert_text "Product created successfully"
    assert_no_selector "turbo-frame#modal form"
    assert_selector "#products article", text: "Gizmo"
  end

  test "editing from the show page and deleting from the list" do
    product = products(:widget)
    visit product_path(product)
    click_on "Edit this product"
    within("turbo-frame#modal") do
      fill_in "Name", with: ""
      assert_text "Name can't be blank"
      fill_in "Name", with: "Widget Deluxe"
      click_on "Save Product"
    end
    assert_text "Product updated successfully"
    assert_selector "h2", text: "Widget Deluxe"

    visit products_path
    accept_confirm { within("#product_#{product.id}") { click_on "Delete" } }
    assert_text "Product deleted"
    assert_no_text "Widget Deluxe"
  end

  test "products saved or restocked elsewhere update every open list without reload" do
    visit products_path
    wait_for_streams
    Product.create!(name: "Fresh Arrival", amount: 1200, stock: 9)
    assert_selector "#products article", text: "Fresh Arrival"

    products(:widget).update!(stock: 0)
    within("#product_#{products(:widget).id}") { assert_text "Out of stock" }
    products(:gadget).update!(name: "Gadget Mk II")
    assert_text "Gadget Mk II"
  end
end
