require "test_helper"

class PaymentJobTest < ActiveJob::TestCase
  test "completes the checkout's payment" do
    cart = Cart.create!
    cart.add_product(products(:widget))
    checkout = cart.create_checkout!(name: "Ada", address: "1 Lane", city: "Leeds", postal_code: "LS1", payment_status: "processing")
    PaymentJob.perform_now(checkout)
    assert cart.reload.completed?
  end
end
