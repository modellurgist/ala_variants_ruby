require "application_system_test_case"

class PortalsTest < ApplicationSystemTestCase
  setup { @pallet = products(:pallet) }

  test "build an order with volume pricing, undo a removal, and submit it with a live-validated PO" do
    visit portal_path
    within("#portal_product_#{products(:sold_out).id}") { assert_button "Add to order", disabled: true }
    within("#portal_product_#{@pallet.id}") do
      fill_in "Quantity for Pallet", with: "4"
      click_on "Add to order"
    end
    assert_text "Added to order"
    within("#portal_summary") { assert_no_text "volume discount" }

    fill_in "Quantity of Pallet", with: "6"
    find_field("Quantity of Pallet").send_keys(:tab)
    within("#portal_summary") { assert_text "5% volume discount" }

    within("#portal_lines") { click_on "Remove" }
    within("#undo_banner") { click_on "Undo" }
    assert_text "Item restored"
    within("#portal_lines") { assert_field "Quantity of Pallet", with: "6" }

    click_on "Review order"
    assert_text "Review order · $570.00"
    fill_in "Purchase order number", with: "PO-1"
    assert_text "must look like PO-1234"
    click_on "Edit lines"
    assert_current_path portal_path
    page.go_back
    fill_in "Purchase order number", with: "PO-2026"
    assert_no_text "must look like PO-1234"
    click_on "Submit order"
    assert_text "Order submitted"
    assert_text Order.last.reference
    assert_text "PO-2026"
  end

  test "stock changes update the catalog row and the affected order line live" do
    visit portal_path
    within("#portal_product_#{@pallet.id}") { click_on "Add to order" }
    assert_text "Added to order"
    wait_for_streams
    @pallet.update!(stock: 0)
    within("#portal_product_#{@pallet.id}") do
      assert_text "Out of stock"
      assert_button "Add to order", disabled: true
    end
    within("#portal_lines") { assert_text "Out of stock" }
  end
end
