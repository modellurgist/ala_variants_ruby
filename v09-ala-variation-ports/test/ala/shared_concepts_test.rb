require "test_helper"

# The concepts the clone check found written twice, each tested once in its own home.
class SharedConceptsTest < ActiveSupport::TestCase
  include Rules

  ROWS = { 7 => { id: 7, name: "Widget", amount: Foundation::Money[1000], thumbnail: "w" },
           8 => { id: 8, name: "Gadget", amount: Foundation::Money[250], thumbnail: "g" } }.freeze
  RATES = { standard: { label: "Standard", cost: 599, free_above: 5000 }, express: { label: "Express", cost: 1299, free_above: nil } }.freeze
  FLOW = [ [ :address, :submit_address, :payment ], [ :payment, :edit_address, :address ], [ :payment, :pay, :processing ] ].freeze

  def held(asked = [], **config)
    HeldProducts.new(products: ->(ids) { asked << ids; ROWS.slice(*ids) }, **config)
  end

  def step_record(finds = [])
    cart = Cart.create!(status: "open")
    ProgrammingParadigms::StepRecord.new(record: -> { finds << 1; Checkout.for_cart(cart.id) }, flow: FLOW, start: :address,
                                         url_edges: [ [ :payment, :address ] ])
  end

  def address = { name: "Ada", line1: "1 Ave", city: "L", postal_code: "12345" }

  test "LineRequest reads a bare product id as one of it" do
    assert_equal({ product_id: 7, quantity: 1 }, LineRequest.call(7))
  end

  test "LineRequest reads a hash request, its quantity as an integer" do
    assert_equal({ product_id: 7, quantity: 3 }, LineRequest.call({ product_id: 7, quantity: "3" }))
  end

  test "LineRequest never asks for fewer than one" do
    assert_equal [ 1, 1, 1 ], [ 0, -2, nil ].map { LineRequest.call({ product_id: 7, quantity: _1 })[:quantity] }
    assert_equal 1, LineRequest.call({ product_id: 7 })[:quantity]
  end

  test "HeldProducts asks for each product once per load and shows rows in order with their links" do
    asked = []
    h = held(asked, links: ->(id) { { remove: "/x/#{id}" } })
    h.load([ { id: 2, product_id: 8 }, { id: 1, product_id: 7 }, { id: 3, product_id: 8 } ])
    assert_equal [ [ 8, 7 ] ], asked
    assert_equal [ 2, 1, 3 ], h.rows.map { _1[:id] }
    assert_equal({ id: 1, name: "Widget", thumbnail: "w", amount: Foundation::Money[1000], urls: { remove: "/x/1" } }, h.rows[1])
  end

  test "HeldProducts rows carry no links unless configured" do
    h = held
    h.load([ { id: 1, product_id: 7 } ])
    assert_equal({}, h.row(h.find(1))[:urls])
  end

  test "HeldProducts asks again on add only for a product it has not seen" do
    asked = []
    h = held(asked)
    h.load([ { id: 1, product_id: 7 } ])
    h.add({ id: 2, product_id: 7 })
    h.add({ id: 3, product_id: 8 })
    assert_equal [ [ 7 ], [ 8 ] ], asked
    assert_equal "Gadget", h.product(h.find(3))[:name]
  end

  test "HeldProducts add replaces an entry with the same id, moving it last" do
    h = held
    h.load([ { id: 1, product_id: 7, quantity: 1 }, { id: 2, product_id: 8 } ])
    h.add({ id: 1, product_id: 7, quantity: 5 })
    assert_equal [ [ 2, nil ], [ 1, 5 ] ], h.entries.map { [ _1[:id], _1[:quantity] ] }
  end

  test "HeldProducts take removes and answers the entry; find raises for what it does not hold" do
    h = held
    h.load([ { id: 1, product_id: 7 }, { id: 2, product_id: 8 } ])
    assert_equal({ id: 1, product_id: 7 }, h.take(1))
    assert_equal [ 2 ], h.entries.map { _1[:id] }
    assert_raises(ArgumentError) { h.find(1) }
    assert_raises(ArgumentError) { h.take(1) }
  end

  test "HeldProducts entries is a copy" do
    h = held
    h.load([ { id: 1, product_id: 7 } ])
    h.entries.clear
    assert_equal 1, h.entries.size
  end

  test "HeldProducts holds bare product ids when each is its own id and product" do
    h = held(id: ->(id) { id }, product_id: ->(id) { id }, links: ->(id) { { add: "/w/#{id}" } })
    h.load([ 8 ])
    h.add(7)
    assert_equal [ 8, 7 ], h.entries
    assert_equal({ id: 7, name: "Widget", thumbnail: "w", amount: Foundation::Money[1000], urls: { add: "/w/7" } }, h.row(7))
  end

  test "StepRecord advances along its table and persists the step; an unlisted event stays" do
    s = step_record
    assert_equal({ step: :payment }, s.advance(:submit_address))
    assert_equal "payment", s.record.reload.step
    assert_equal({ step: :payment }, s.advance(:submit_address))
    assert_equal "payment", s.record.reload.step
  end

  test "StepRecord shows a URL's step only along an allowed jump" do
    s = step_record
    assert_equal :address, s.show(:payment)[:step]
    s.advance(:submit_address)
    assert_equal :payment, s.show(nil)[:step]
    assert_equal :payment, s.show(:processing)[:step]
    shown = s.show(:address)
    assert_equal :address, shown[:step]
    assert_equal "address", s.record.reload.step
    assert_same s.record, shown[:form]
  end

  test "StepRecord asks for its record once" do
    finds = []
    s = step_record(finds)
    s.show(nil)
    s.advance(:submit_address)
    s.restart
    assert_equal 1, finds.size
  end

  test "StepRecord validates in a context without saving" do
    s = step_record
    form = s.validate({ name: "Ada", postal_code: "x" }, :address)[:form]
    assert form.errors.key?(:postal_code)
    assert form.errors.key?(:city)
    assert_nil Checkout.find(form.id).name
  end

  test "StepRecord submit that fails validation stays, carries the errors and skips the block" do
    s = step_record
    out = s.submit({ name: "Ada" }, context: :address, event: :submit_address) { flunk "the block ran" }
    assert_equal :address, out[:step]
    assert out[:form].errors.key?(:city)
    assert_nil Checkout.find(out[:form].id).name
  end

  test "StepRecord submit saves, moves on by the event and merges what the block answers for the saved record" do
    s = step_record
    out = s.submit(address, context: :address, event: :submit_address) { { saved_name: _1.reload.name } }
    assert_equal({ step: :payment, saved_name: "Ada" }, out)
    assert_equal "payment", s.record.reload.step
    assert_equal({ step: :address }, step_record.submit(address, context: :address, event: :pay))
  end

  test "StepRecord restart returns to the start from anywhere" do
    s = step_record
    s.advance(:submit_address)
    s.advance(:pay)
    assert_equal({ step: :address }, s.restart)
    assert_equal "address", s.record.reload.step
  end

  test "CartItem#to_line is the neutral shape of a stored line" do
    cart = Cart.create!(status: "open")
    item = CartItem.add(cart.id, create_product.id, 2)
    item.update!(gift_wrapped: true)
    assert_equal({ id: item.id, product_id: item.product_id, quantity: 2, gift_wrapped: true }, item.to_line)
  end

  def summary(lines, method: :standard, percentage: nil, extras: 0)
    Pricing.summary(lines, percentage:, shipping: CalculateShipping.new(rates: RATES), method:, extras:)
  end

  test "Pricing.summary: subtotal, discount, extras after it, shipping and total" do
    s = summary([ { quantity: 2, amount: 1000 }, { quantity: 1, amount: 500 } ], percentage: 10, extras: 299)
    assert_equal [ false, 3, "Standard" ], s.values_at(:empty, :item_count, :shipping_label)
    assert_equal [ "$25.00", "$2.50", "$5.99", "$31.48" ], s.values_at(:subtotal, :discount, :shipping_cost, :total).map(&:to_s)
  end

  test "Pricing.summary decides free shipping on the subtotal, before the discount" do
    s = summary([ { quantity: 1, amount: 5000 } ], percentage: 10)
    assert_equal "$0.00", s[:shipping_cost].to_s
    assert_equal "$45.00", s[:total].to_s
  end

  test "Pricing.summary charges a method without a free threshold however large the subtotal" do
    assert_equal "$12.99", summary([ { quantity: 1, amount: 9000 } ], method: :express)[:shipping_cost].to_s
  end

  test "Pricing.summary rounds a fractional discount down to the cent" do
    s = summary([ { quantity: 1, amount: 999 } ], percentage: 15)
    assert_equal "$1.49", s[:discount].to_s
    assert_equal "$14.49", s[:total].to_s
  end

  test "Pricing.summary of no lines is empty and free" do
    s = summary([], percentage: 10)
    assert s[:empty]
    assert_equal [ 0, "$0.00", "$0.00", "$0.00" ], [ s[:item_count], s[:subtotal].to_s, s[:shipping_cost].to_s, s[:total].to_s ]
  end
end
