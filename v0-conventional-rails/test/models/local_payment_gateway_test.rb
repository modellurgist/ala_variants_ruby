require "test_helper"

class LocalPaymentGatewayTest < ActiveSupport::TestCase
  test "settles at once and returns the app's own success URL" do
    assert_equal "/cart/success", LocalPaymentGateway.new.checkout(line_items: [ { name: "W", unit_amount: 1, quantity: 1 } ], success_url: "/cart/success")
  end

  test "declines an empty session" do
    assert_nil LocalPaymentGateway.new.checkout(line_items: [], success_url: "/cart/success")
  end

  test "is the configured default" do
    assert_equal "LocalPaymentGateway", Rails.application.config_for(:store)[:payment_gateway]
  end
end
