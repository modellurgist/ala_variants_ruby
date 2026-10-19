require "test_helper"

class CartTotalsTest < ActiveSupport::TestCase
  setup { @cart = Cart.create! }

  test "an empty cart totals zero and ships free" do
    totals = @cart.totals
    assert totals.empty?
    assert_equal [ 0, 0, 0, "Free", 0 ], [ totals.item_count, totals.subtotal, totals.shipping, totals.shipping_label, totals.total ]
  end

  test "subtotal, item count, and standard shipping" do
    @cart.add_product(products(:widget), quantity: 2)
    @cart.add_product(products(:gadget))
    totals = @cart.totals
    assert_equal 3, totals.item_count
    assert_equal 4500, totals.subtotal
    assert_equal [ 599, "Standard (5–7 days)" ], [ totals.shipping, totals.shipping_label ]
    assert_equal 5099, totals.total
  end

  test "standard shipping is free from 5000; other methods always charge" do
    @cart.add_product(products(:widget), quantity: 5)
    assert_equal [ 0, "Free" ], [ @cart.totals.shipping, @cart.totals.shipping_label ]
    @cart.update!(shipping_method: "express")
    assert_equal [ 1299, "Express (2–3 days)" ], [ @cart.totals.shipping, @cart.totals.shipping_label ]
    @cart.update!(shipping_method: "overnight")
    assert_equal 2499, @cart.totals.shipping
  end

  test "promo discount, gift wrap per wrapped item, and the total" do
    @cart.add_product(products(:widget), quantity: 2).update!(gift_wrap: true)
    @cart.add_product(products(:gadget)).update!(gift_wrap: true)
    @cart.apply_promo_code("SAVE20")
    totals = @cart.totals
    assert_equal 20, totals.promo_percent
    assert_equal 900, totals.discount
    assert_equal 598, totals.gift_wrap
    assert_equal 4500 - 900 + 598 + 599, totals.total
  end

  test "every configured promo code applies its percentage" do
    @cart.add_product(products(:widget))
    { "SAVE10" => 100, "SAVE20" => 200, "HALF" => 500 }.each do |code, discount|
      @cart.apply_promo_code(code)
      assert_equal discount, @cart.totals.discount
    end
  end

  test "portal carts reprice by volume tier across boundaries and ignore promo and gift wrap" do
    portal = Cart.create!(kind: :portal, promo_code: "HALF")
    line = portal.add_product(products(:pallet), quantity: 4)
    line.update!(gift_wrap: true)
    assert_nil portal.totals.volume_tier
    assert_equal [ 0, 0, 0 ], [ portal.totals.discount, portal.totals.gift_wrap, portal.totals.volume_discount ]

    line.update!(quantity: 5)
    assert_equal "5% volume discount", portal.totals.volume_tier[:label]
    assert_equal 2500, portal.totals.volume_discount
    assert_equal 50_000 - 2500, portal.totals.total

    line.update!(quantity: 20)
    assert_equal "10% volume discount", portal.totals.volume_tier[:label]
    assert_equal 20_000, portal.totals.volume_discount

    line.update!(quantity: 3)
    assert_nil portal.totals.volume_tier
  end
end
