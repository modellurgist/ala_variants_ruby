require "test_helper"

# Unit tests of the domain abstractions: each is called directly and judged by what it returns.
class DomainTest < ActiveSupport::TestCase
  include DomainAbstractions
  include Rules

  RATES = { standard: { label: "Standard", cost: 599, free_above: 5000 }, express: { label: "Express", cost: 1299, free_above: nil } }.freeze

  test "Pricing sums, counts and discounts in cents" do
    lines = [ { quantity: 2, amount: 1000 }, { quantity: 1, amount: 500 } ]
    assert_equal 2500, Pricing.subtotal(lines)
    assert_equal 3, Pricing.item_count(lines)
    assert_equal [ 900, 100 ], Pricing.apply_discount(1000, 10)
    assert_equal [ 1000, 0 ], Pricing.apply_discount(1000, nil)
  end

  test "CalculateShipping honours free thresholds, per-method costs and an empty cart" do
    shipping = CalculateShipping.new(rates: RATES)
    assert_equal 0, shipping.call(:standard, 0)
    assert_equal 599, shipping.call(:standard, 100)
    assert_equal 0, shipping.call(:standard, 5000)
    assert_equal 1299, shipping.call(:express, 100)
    assert_equal "Express", shipping.label(:express)
  end

  test "ValidatePromo normalises codes; StockStatus classifies" do
    assert_equal [ "SAVE10", 10 ], ValidatePromo.new(codes: { "SAVE10" => 10 }).call("  save10 ")
    assert_nil ValidatePromo.new(codes: { "SAVE10" => 10 }).call("nope")
    rule = StockStatus.new(low_at: 5)
    assert_equal %i[out_of_stock low_stock in_stock], [ 0, 3, 50 ].map { rule.call(_1) }
  end

  test "CheckStock compares quantities to levels" do
    lines = [ { product_id: 7, quantity: 2 } ]
    assert CheckStock.call(lines, { 7 => 5 })
    assert_not CheckStock.call(lines, { 7 => 1 })
  end

  test "CartTotals joins contents, discount and shipping into one summary" do
    totals = CartTotals.new(shipping: CalculateShipping.new(rates: RATES), gift_wrap: CalculateGiftWrapCost.new(unit: 299))
    totals.shipping_method(:standard)
    totals.contents(lines: [ { quantity: 2, amount: 1000 } ], wrapped_count: 1)
    summary = totals.discount(code: "SAVE10", percentage: 10)[:summary]
    assert_equal "$20.00", summary[:subtotal].to_s
    assert_equal "$2.00", summary[:discount].to_s
    assert_equal "$2.99", summary[:gift_wrap_total].to_s
    assert_equal "$26.98", summary[:total].to_s
  end

  test "Undo holds only the latest removal, unwrapped, and restores it within the window" do
    cart = Cart.create!(status: "open")
    a = CartItem.add(cart.id, create_product(name: "A").id)
    b = CartItem.add(cart.id, create_product(name: "B").id)
    b.update!(gift_wrapped: true)
    undo = Undo.new(lines: CartItem, cart_id: cart.id, window: 5.seconds)

    undo.capture(a.id)
    assert_equal true, undo.capture(b.id)
    assert_not CartItem.exists?(a.id)

    assert_equal({ id: b.id, product_id: b.product_id, quantity: 1, gift_wrapped: false }, undo.restore)
    assert_nil b.reload.removed_at
    assert_equal false, undo.load
    assert_nil undo.restore
  end

  test "CheckoutFlow follows the page's table: an address first, a forward jump ignored, then payment" do
    cart = Cart.create!(status: "open")
    product = create_product(stock: 1)
    CartItem.add(cart.id, product.id)
    index = ProductIndex.new(model: Product, project: ProductRow.new(stock_rule: StockStatus.new(low_at: 5)))
    lines = CartLines.new(cart_id: cart.id, held: HeldProducts.new(products: ->(ids) { index.lookup(ids) }))
    lines.load(CartItemsStore.new(model: CartItem, cart_id: cart.id).lookup)
    steps = ProgrammingParadigms::StepRecord.new(record: -> { Checkout.for_cart(cart.id) }, flow: Screens::Checkout::FLOW, start: :address,
                                                 url_edges: Screens::Checkout::URL_EDGES)
    flow = CheckoutFlow.new(steps:, stock_levels: ->(ids) { Product.stock_levels(ids) }, line_items: BuildLineItems.new(currency: "usd"))

    assert_equal :empty, flow.start({ cart_id: cart.id, lines: [] })
    assert_nil flow.start(lines.lines)
    calls = [ -> { steps.show(:payment) }, -> { steps.submit({ name: "Ada", line1: "1 Ave", city: "L", postal_code: "12345" }, context: :address, event: :submit_address) }, -> { steps.show(:address) } ]
    assert_equal %i[address payment address], calls.map { _1.(); steps.step }

    steps.advance(:submit_address)
    product.update!(stock: 0)
    assert_equal({ blocked: :out_of_stock }, flow.pay(lines.lines))
    product.update!(stock: 1)
    assert_equal [ product.name ], flow.pay(lines.lines)[:payment][:line_items].map { _1[:name] }
    assert_equal :processing, steps.step
  end
end
