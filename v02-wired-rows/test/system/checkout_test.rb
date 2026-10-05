require "application_system_test_case"

class CheckoutSystemTest < ApplicationSystemTestCase
  test "address, payment, the payment job, and the live redirect to the success page" do
    product = create_product(name: "Widget", amount: 1000, stock: 3)
    visit products_path
    click_on "Add to cart"
    visit cart_path
    click_on "Checkout"
    fill_in "Full name", with: "Ada"
    fill_in "Address", with: "1 Lane"
    fill_in "City", with: "Leeds"
    fill_in "Postal code", with: "12345"
    click_on "Continue to payment"
    assert_text "Ada"
    assert_selector "turbo-cable-stream-source[connected]", visible: :all
    click_on "Pay"
    assert_text "Processing payment…"
    perform_enqueued_jobs(only: ProgrammingParadigms::PushLater)
    assert_text "Thanks for your business!", wait: 10
    assert_equal 2, product.reload.stock
  end
end
