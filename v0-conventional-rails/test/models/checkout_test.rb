require "test_helper"

class CheckoutTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  setup do
    @cart = Cart.create!
    @cart.add_product(products(:widget), quantity: 2)
    @checkout = @cart.create_checkout!(name: "Ada", address: "1 Lane", city: "Leeds", postal_code: "LS1")
  end

  test "requires every address field" do
    checkout = Checkout.new(cart: @cart)
    assert_not checkout.valid?
    assert_equal %i[name address city postal_code], checkout.errors.attribute_names
  end

  test "starting payment marks it processing and runs it in the background" do
    assert_enqueued_with(job: PaymentJob, args: [ @checkout ]) { @checkout.start_payment! }
    assert @checkout.processing?
  end

  test "opens a gateway session with the cart's line items and the success URL" do
    @checkout.complete_payment
    assert_equal [ [ { name: "Widget", unit_amount: 1000, quantity: 2 } ] ], FakePaymentGateway.sessions
  end

  test "a successful payment places the order, decrements stock, and sends the shopper to the success page" do
    streams = capture_turbo_stream_broadcasts(@checkout) do
      assert_turbo_stream_broadcasts("products", count: 1) { @checkout.complete_payment }
    end
    assert_equal [ "redirect", "/cart/success" ], [ streams.sole["action"], streams.sole["url"] ]
    assert @cart.reload.completed?
    assert_equal 2, @cart.order.order_items.sole.quantity
    assert_equal 8, products(:widget).reload.stock
  end

  test "a failed payment shows the failure with a retry, and changes nothing else" do
    FakePaymentGateway.declines = true
    @checkout.processing!
    streams = capture_turbo_stream_broadcasts(@checkout) { @checkout.complete_payment }
    assert @checkout.reload.failed?
    assert_match "Payment failed.", streams.sole.to_html
    assert_match "Retry payment", streams.sole.to_html
    assert @cart.reload.open?
    assert_equal 10, products(:widget).reload.stock
  end

  test "the gateway is configurable and defaults to the in-process one" do
    assert_instance_of FakePaymentGateway, Checkout.gateway
    Rails.configuration.x.store.payment_gateway = "LocalPaymentGateway"
    assert_instance_of LocalPaymentGateway, Checkout.gateway
  ensure
    Rails.configuration.x.store.payment_gateway = "FakePaymentGateway"
  end
end
