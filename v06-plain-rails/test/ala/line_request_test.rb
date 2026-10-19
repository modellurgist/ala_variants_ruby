require "test_helper"

class LineRequestTest < ActiveSupport::TestCase
  test "a product id alone asks for one of it" do
    assert_equal({ product_id: 7, quantity: 1 }, Rules::LineRequest.call(7))
  end

  test "a hash names the product and the quantity" do
    assert_equal({ product_id: 7, quantity: 3 }, Rules::LineRequest.call(product_id: 7, quantity: 3))
    assert_equal({ product_id: 7, quantity: 4 }, Rules::LineRequest.call(product_id: 7, quantity: "4"))
  end

  test "a quantity below one, or none, is one" do
    assert_equal [ 1, 1, 1 ], [ { quantity: 0 }, { quantity: -2 }, {} ].map { Rules::LineRequest.call(product_id: 7, **_1)[:quantity] }
  end
end
