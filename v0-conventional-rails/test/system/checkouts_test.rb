require "application_system_test_case"

class CheckoutsTest < ApplicationSystemTestCase
  def fill_in_address
    fill_in "Full name", with: "Ada Lovelace"
    fill_in "Address", with: "1 Lane"
    fill_in "City", with: "Leeds"
    fill_in "Postal code", with: "LS1"
  end

  test "address with live validation, payment processing, then the success page; stock drops live elsewhere" do
    product = products(:widget)
    add_to_cart(product)
    visit cart_path
    click_on "Checkout"
    fill_in "Full name", with: "Ada"
    fill_in "Full name", with: ""
    assert_text "Name can't be blank"
    fill_in_address
    assert_no_text "Name can't be blank"
    click_on "Continue to payment"

    assert_current_path payment_cart_checkout_path
    assert_text "Ada Lovelace"
    assert_text "Total: $15.99"
    wait_for_streams

    using_session(:other_shopper) do
      visit products_path
      wait_for_streams
    end

    click_on "Pay"
    assert_text "Processing payment…"
    assert_no_button "Pay"
    assert_no_link "Edit address"
    perform_enqueued_jobs(only: PaymentJob)
    assert_text "Thank you for your order!"
    assert_current_path success_cart_path
    assert_equal 9, product.reload.stock

    using_session(:other_shopper) do
      within("#product_#{product.id}") { assert_text "Stock: 9" }
    end
  end

  test "a failed payment offers a retry that pays again" do
    FakePaymentGateway.declines = true
    add_to_cart(products(:widget))
    visit cart_path
    click_on "Checkout"
    fill_in_address
    click_on "Continue to payment"
    assert_text "Ship to"
    wait_for_streams
    click_on "Pay"
    assert_text "Processing payment…"
    perform_enqueued_jobs(only: PaymentJob)
    assert_text "Payment failed."

    FakePaymentGateway.declines = false
    click_on "Retry payment"
    assert_text "Processing payment…"
    perform_enqueued_jobs(only: PaymentJob)
    assert_text "Thank you for your order!"
  end

  test "browser back returns to the previous step, edit address goes back, and forward jumps are ignored" do
    add_to_cart(products(:widget))
    visit payment_cart_checkout_path
    assert_current_path cart_checkout_path

    fill_in_address
    click_on "Continue to payment"
    assert_text "Ship to"
    page.go_back
    assert_current_path cart_checkout_path
    assert_field "Full name", with: "Ada Lovelace"
    page.go_forward
    assert_text "Ship to"
    click_on "Edit address"
    assert_current_path cart_checkout_path
    page.refresh
    assert_field "City", with: "Leeds"
  end

  test "checkout is disabled for an empty cart" do
    visit cart_path
    assert_text "Your cart is empty."
    assert_button "Checkout", disabled: true
  end
end
