require "test_helper"

class CheckoutsControllerTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  ADDRESS = { name: "Ada Lovelace", address: "1 Lane", city: "Leeds", postal_code: "LS1" }.freeze

  def enter_address
    patch cart_checkout_path, params: { checkout: ADDRESS }
  end

  test "starting checkout with an empty cart flashes and stays on the cart" do
    post cart_checkout_path
    assert_redirected_to cart_path
    assert_equal "Your cart is empty", flash[:alert]
  end

  test "starting checkout goes to the Address step" do
    add_to_cart(products(:widget))
    post cart_checkout_path
    assert_redirected_to cart_checkout_path
    follow_redirect!
    assert_select "li[aria-current=step]", /Address/
    assert_select "li[data-step-state=upcoming]", /Payment/
    assert_select "form[data-controller=live-validation]"
  end

  test "the address needs every field; a valid address advances to Payment" do
    add_to_cart(products(:widget))
    patch cart_checkout_path, params: { checkout: ADDRESS.merge(city: "") }
    assert_response :unprocessable_entity
    assert_select "#checkout_errors li", "City can't be blank"
    enter_address
    assert_redirected_to payment_cart_checkout_path
  end

  test "live validation of the address" do
    add_to_cart(products(:widget))
    post validate_cart_checkout_path, params: { checkout: ADDRESS.merge(name: "") }, headers: turbo_stream
    assert_turbo_stream action: "update", target: "checkout_errors" do
      assert_select "li", "Name can't be blank"
    end
  end

  test "payment shows the address summary, total, Edit address, and Pay" do
    add_to_cart(products(:widget))
    enter_address
    get payment_cart_checkout_path
    assert_select "li[data-step-state=done]", /Address/
    assert_select "li[aria-current=step]", /Payment/
    assert_select "p", "Ada Lovelace"
    assert_select "p", "Total: $15.99"
    assert_select "a[href=?]", cart_checkout_path, text: "Edit address"
    assert_select "button", "Pay"
  end

  test "a forward jump to Payment without an address is ignored; reloading a reached step lands on it" do
    add_to_cart(products(:widget))
    get payment_cart_checkout_path
    assert_redirected_to cart_checkout_path
    enter_address
    get payment_cart_checkout_path
    assert_response :success
    get cart_checkout_path
    assert_select "input[value=?]", "Ada Lovelace"
  end

  test "pay starts the payment in the background and shows it processing" do
    add_to_cart(products(:widget))
    enter_address
    assert_enqueued_with(job: PaymentJob) { post pay_cart_checkout_path }
    assert_redirected_to payment_cart_checkout_path
    follow_redirect!
    assert_select "#payment [role=status]", "Processing payment…"
    assert_select "#payment button", count: 0
    assert_select "#payment a", count: 0
    assert_no_enqueued_jobs(only: PaymentJob) { post pay_cart_checkout_path }
  end

  test "pay from the page swaps the panel to processing in place" do
    add_to_cart(products(:widget))
    enter_address
    post pay_cart_checkout_path, headers: turbo_stream
    assert_turbo_stream action: "replace", target: "payment" do
      assert_select "[role=status]", "Processing payment…"
    end
  end

  test "pay with an item short of stock flashes and does not charge" do
    add_to_cart(products(:gadget)).update!(quantity: 4)
    enter_address
    assert_no_enqueued_jobs { post pay_cart_checkout_path }
    assert_redirected_to payment_cart_checkout_path
    assert_equal "Some items are out of stock", flash[:alert]
  end

  test "pay with an empty cart flashes" do
    item = add_to_cart(products(:widget))
    enter_address
    item.destroy!
    post pay_cart_checkout_path
    assert_redirected_to cart_path
    assert_equal "Your cart is empty", flash[:alert]
  end

  test "pay before entering an address goes back to the Address step" do
    add_to_cart(products(:widget))
    post pay_cart_checkout_path
    assert_redirected_to cart_checkout_path
  end

  test "a successful payment completes the cart; the payment URL then leads to the success page" do
    add_to_cart(products(:widget))
    enter_address
    post pay_cart_checkout_path
    perform_enqueued_jobs
    assert current_cart.completed?
    get payment_cart_checkout_path
    assert_redirected_to success_cart_path
    follow_redirect!
    assert_select "h1", "Thank you for your order!"
    get cart_path
    assert current_cart.open?
    assert_select "#cart_summary p", "Your cart is empty."
  end

  test "a failed payment shows the failure and a retry that pays again" do
    FakePaymentGateway.declines = true
    add_to_cart(products(:widget))
    enter_address
    post pay_cart_checkout_path
    perform_enqueued_jobs
    get payment_cart_checkout_path
    assert_select "#payment [role=alert]", "Payment failed."
    assert_select "#payment button", "Retry payment"

    FakePaymentGateway.declines = false
    post pay_cart_checkout_path
    perform_enqueued_jobs
    assert current_cart.completed?
    assert_equal 2, FakePaymentGateway.sessions.size
  end
end
