require "test_helper"

class LineRowTest < ActiveSupport::TestCase
  PRODUCTS = { 7 => { id: 7, name: "Widget", amount: 1000 }, 8 => { id: 8, name: "Gadget", amount: 500 }, 9 => { id: 9, name: "Gizmo", amount: 250 } }.freeze

  setup { @lookups = [] }

  def rows(links: ->(_id) { {} }) = Rules::LineRow.new(products: ->(ids) { @lookups << ids; PRODUCTS.slice(*ids) }, links:)

  test "a row is the product's row overlaid with the line's fields, its id among them, and the line's URLs" do
    row = rows(links: ->(id) { { remove: "/lines/#{id}" } }).call(id: 42, product_id: 7, quantity: 2)
    assert_equal({ id: 42, name: "Widget", amount: 1000, product_id: 7, quantity: 2, urls: { remove: "/lines/42" } }, row)
  end

  test "each product is looked up once however many lines name it" do
    r = rows
    r.call(id: 1, product_id: 7, quantity: 1)
    r.call(id: 2, product_id: 7, quantity: 3)
    assert_equal({ id: 7, name: "Widget", amount: 1000 }, r.product(7))
    assert_equal [ [ 7 ] ], @lookups
  end

  test "fill looks up a batch in one call, asking only for products not yet held" do
    r = rows
    r.fill([ 7, 8, 7 ])
    r.call(id: 1, product_id: 8, quantity: 1)
    r.fill([ 8, 9 ])
    r.fill([ 7, 9 ])
    assert_equal [ [ 7, 8 ], [ 9 ] ], @lookups
  end
end
