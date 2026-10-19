require "test_helper"

class PricingSummaryTest < ActiveSupport::TestCase
  SHIPPING = Rules::CalculateShipping.new(rates: { standard: { label: "Standard", cost: 599, free_above: 5000 } })

  def summary(lines, percentage: nil, extra: 0) = Rules::Pricing.summary(lines, percentage:, shipping: SHIPPING, method: :standard, extra:)
  def money(cents) = Foundation::Money[cents]

  test "the total is the subtotal less the discount, plus the extra and the shipping" do
    lines = [ { quantity: 2, amount: 1000 }, { quantity: 1, amount: 500 } ]
    assert_equal({ empty: false, item_count: 3, subtotal: money(2500), discount: money(250), shipping_label: "Standard", shipping_cost: money(599),
                   total: money(2500 - 250 + 299 + 599) }, summary(lines, percentage: 10, extra: 299))
  end

  test "the discount rounds down to the cent" do
    s = summary([ { quantity: 1, amount: 999 } ], percentage: 15)
    assert_equal money(149), s[:discount]
    assert_equal money(999 - 149 + 599), s[:total]
  end

  test "free shipping is judged on the subtotal before the discount" do
    s = summary([ { quantity: 1, amount: 5000 } ], percentage: 10)
    assert_equal money(0), s[:shipping_cost]
    assert_equal money(4500), s[:total]
  end

  test "no percentage means no discount, and the extra defaults to nothing" do
    s = summary([ { quantity: 1, amount: 1000 } ])
    assert_equal money(0), s[:discount]
    assert_equal money(1000 + 599), s[:total]
  end

  test "an empty list is empty, ships free and totals only the extra" do
    assert_equal({ empty: true, item_count: 0, subtotal: money(0), discount: money(0), shipping_label: "Standard", shipping_cost: money(0), total: money(299) },
                 summary([], percentage: 10, extra: 299))
  end
end
