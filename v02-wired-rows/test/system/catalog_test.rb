require "application_system_test_case"

class CatalogSystemTest < ApplicationSystemTestCase
  test "the modal form validates live and a saved product lands in the list" do
    create_product(name: "Widget")
    visit products_path
    click_on "New Product"
    within "turbo-frame#modal" do
      fill_in "Amount (cents)", with: "500"
      assert_text "Name can't be blank"
      fill_in "Name", with: "Gizmo"
      click_on "Save Product"
    end
    assert_text "Product created successfully"
    assert_selector "#products", text: "Gizmo"
    assert_no_selector "turbo-frame#modal form"
  end
end
