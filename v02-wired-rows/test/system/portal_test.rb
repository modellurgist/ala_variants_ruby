require "application_system_test_case"

class PortalSystemTest < ApplicationSystemTestCase
  test "adding at quantity earns a volume tier, and the purchase order validates live before submitting" do
    create_product(name: "Pallet", amount: 10_000, stock: 50)
    visit portal_path
    fill_in "quantity", with: "6"
    click_on "Add"
    assert_text "Added to order"
    assert_text "5% volume discount"
    click_on "Review order"
    fill_in "Purchase order number", with: "bad"
    assert_text "must look like PO-1234"
    fill_in "Purchase order number", with: "PO-1234"
    assert_no_text "must look like PO-1234"
    click_on "Submit order"
    assert_text "Order submitted"
    assert_text "PO-1234"
  end
end
