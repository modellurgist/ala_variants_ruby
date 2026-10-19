require "test_helper"

class PricingControllersTest < ActionDispatch::IntegrationTest
  setup { add_to_cart(products(:widget)) }

  test "a valid promo code flashes and shows the discount" do
    patch cart_promo_code_path, params: { code: "save10" }, headers: turbo_stream
    assert_equal "SAVE10", current_cart.promo_code
    assert_stream_text "flash", /Promo applied!/
    assert_turbo_stream action: "update", target: "cart_summary" do
      assert_select "dt", "Discount (SAVE10)"
    end
  end

  test "an invalid promo code flashes, shows the error inline, and leaves the cart unchanged; a valid one clears it" do
    patch cart_promo_code_path, params: { code: "NOPE" }, headers: turbo_stream
    assert_nil current_cart.promo_code
    assert_stream_text "flash", /Invalid promo code/
    assert_turbo_stream action: "update", target: "promo_form" do
      assert_select "p", "Invalid promo code"
    end
    patch cart_promo_code_path, params: { code: "HALF" }, headers: turbo_stream
    assert_turbo_stream action: "update", target: "promo_form" do
      assert_select "p", count: 0
    end
  end

  test "choosing a shipping method reprices with its label" do
    get cart_path
    assert_select "input[type=radio][name=shipping_method]", 3
    patch cart_shipping_method_path, params: { shipping_method: "overnight" }, headers: turbo_stream
    assert_equal "overnight", current_cart.shipping_method
    assert_turbo_stream action: "update", target: "cart_summary" do
      assert_select "dt", "Shipping (Overnight)"
      assert_select "dd", "$24.99"
    end
  end
end
