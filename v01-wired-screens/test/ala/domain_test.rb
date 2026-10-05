require "test_helper"

# Unit tests of the domain abstractions: pure ones called directly, ported ones with fakes on their ports.
class DomainTest < ActiveSupport::TestCase
  include DomainAbstractions

  Recorder = Struct.new(:got) do
    include Foundation::Ports
    input(:input, ProgrammingParadigms::DataFlow) { |x| (self.got ||= []) << x }
  end

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

  test "ValidatePromo normalises codes; VolumeTier picks the highest tier reached; StockStatus classifies" do
    assert_equal [ "SAVE10", 10 ], ValidatePromo.new(codes: { "SAVE10" => 10 }).call("  save10 ")
    assert_nil ValidatePromo.new(codes: { "SAVE10" => 10 }).call("nope")
    tiers = VolumeTier.new(tiers: [ [ 200_000, 10, "10%" ], [ 50_000, 5, "5%" ] ])
    assert_equal [ 5, "5%" ], tiers.call(60_000)
    assert_equal [ 0, nil ], tiers.call(100)
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
    totals.wire_to(out = Recorder.new)
    totals.input_port(:shipping_method).push(:standard)
    totals.input_port(:contents).push(lines: [ { quantity: 2, amount: 1000 } ], wrapped_count: 1)
    totals.input_port(:discount).push(code: "SAVE10", percentage: 10)
    summary = out.got.last
    assert_equal "$20.00", summary[:subtotal].to_s
    assert_equal "$2.00", summary[:discount].to_s
    assert_equal "$2.99", summary[:gift_wrap_total].to_s
    assert_equal "$26.98", summary[:total].to_s
  end

  test "Undo holds only the latest removal and restores it within the window" do
    cart = Cart.create!(status: "open")
    a = CartItem.add(cart.id, create_product(name: "A").id)
    b = CartItem.add(cart.id, create_product(name: "B").id)
    undo = Undo.new(lines: CartItem, cart_id: cart.id, window: 5.seconds)
    undo.wire_to(restored = Recorder.new, from: :restored).wire_to(expired = Recorder.new, from: :expired)

    undo.input_port(:capture).push(a.id)
    undo.input_port(:capture).push(b.id)
    assert_equal [ a.id ], expired.got
    assert_not CartItem.exists?(a.id)

    undo.input_port(:restore).send_event
    assert_equal [ b.id ], restored.got
    assert_nil b.reload.removed_at
  end

  test "CheckoutFlow follows its table and ignores a forward jump" do
    cart = Cart.create!(status: "open")
    CartItem.add(cart.id, create_product.id)
    lines = CartLines.new(lines: CartItem, cart_id: cart.id, stock_rule: StockStatus.new(low_at: 5))
    flow = CheckoutFlow.new(store: Checkout, cart_id: cart.id, flow: Screens::Checkout::FLOW, start: :address,
                            url_edges: Screens::Checkout::URL_EDGES, stock_levels: ->(ids) { Product.stock_levels(ids) },
                            line_items: BuildLineItems.new(currency: "usd"))
    flow.wire_to(lines, from: :lines, to: :lines).wire_to(steps = Recorder.new, from: :step)

    flow.input_port(:start).send_event
    flow.input_port(:show).push(:payment)
    flow.input_port(:submit_address).push(name: "Ada", line1: "1 Ave", city: "L", postal_code: "12345")
    flow.input_port(:show).push(:address)
    assert_equal %i[address address payment address], steps.got
  end
end
