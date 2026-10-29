require "test_helper"

# A change made elsewhere reaches each open page: the change publishes a fact, and the page's live
# URL answers that fact with the page's own patches (R2.5, R2.6, R3.14, R6.8, R8.1).
class ChangeFeedUpdatesTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  CATALOG = Screens::Store::CATALOG_TOPIC

  setup do
    FakeGateway.reset
    @product = create_product(name: "Widget", amount: 1000, stock: 10)
  end

  def deliver(path, kind, **fields) = post(path, params: { fact: { kind:, **fields } }, as: :json)
  def actions = response.body.scan(/<turbo-stream action="(\w+)" targets?="([^"]+)"/)

  def published(topic, &change)
    before = broadcasts(topic).size
    change.()
    broadcasts(topic).drop(before).map { JSON.parse(_1) }
  end

  test "a product saved, changed or deleted publishes its id; a staff edit publishes its stock too" do
    created = published(CATALOG) { post products_path, params: { product: { name: "New", amount: 5, stock: 2 } } }
    id = Product.find_by!(name: "New").id
    assert_equal [ { "kind" => "product_added", "product_id" => id } ], created
    changed = published(CATALOG) { patch product_path(id), params: { product: { stock: 0 } } }
    assert_equal [ { "kind" => "product_changed", "product_id" => id }, { "kind" => "stock", "product_id" => id, "stock" => 0 } ], changed
    assert_equal [ { "kind" => "product_removed", "product_id" => id } ], published(CATALOG) { delete product_path(id) }
  end

  test "the product list appends, replaces and removes the row, and replaces the stock badges" do
    deliver live_products_path, "product_added", product_id: @product.id
    assert_equal [ [ "append", "products" ] ], actions
    assert_match(/Widget.*Edit/m, response.body)
    deliver live_products_path, "product_changed", product_id: @product.id
    assert_equal [ [ "replace", "product_#{@product.id}" ] ], actions
    deliver live_products_path, "product_removed", product_id: @product.id
    assert_equal [ [ "remove", "product_#{@product.id}" ] ], actions
    deliver live_products_path, "stock", product_id: @product.id, stock: 0
    assert_equal [ [ "replace", ".stock_#{@product.id}" ] ], actions
    assert_match(/Out of stock/, response.body)
  end

  test "a change to a product deleted since answers an empty row, not an error" do
    id = @product.id
    @product.destroy!
    deliver live_products_path, "product_changed", product_id: id
    assert_response :success
    assert_equal [ [ "replace", "product_#{id}" ] ], actions
  end

  test "an open cart replaces the product's stock badges and ignores what it does not listen to" do
    get cart_path
    deliver live_cart_path, "stock", product_id: @product.id, stock: 2
    assert_equal [ [ "replace", ".stock_#{@product.id}" ] ], actions
    assert_match(/Only 2 left!/, response.body)
    deliver live_cart_path, "product_changed", product_id: @product.id
    assert_empty actions
  end

  test "the portal renders its own catalogue row, never the product list's" do
    get portal_path
    deliver live_portal_path, "product_changed", product_id: @product.id
    assert_equal [ [ "replace", "product_#{@product.id}" ] ], actions
    assert_match(%r{action="/portal/lines"}, response.body)
    assert_no_match(/Edit|Add to cart/, response.body)
    deliver live_portal_path, "product_added", product_id: @product.id
    assert_equal [ [ "append", "portal_products" ] ], actions
    deliver live_portal_path, "product_removed", product_id: @product.id
    assert_equal [ [ "remove", "product_#{@product.id}" ] ], actions
  end

  test "the portal's catalogue row and every badge follow a stock change, the add disabled when out" do
    get portal_path
    @product.update!(stock: 0)
    deliver live_portal_path, "stock", product_id: @product.id, stock: 0
    assert_equal [ [ "replace", "product_#{@product.id}" ], [ "replace", ".stock_#{@product.id}" ] ], actions
    assert_match(/disabled="disabled"/, response.body)
  end

  test "a paid or declined payment publishes on its checkout's topic, and the waiting page shows the outcome" do
    get cart_path
    cart_id = session[:cart_id]
    CartItem.add(cart_id, @product.id)
    post cart_checkout_path
    patch address_cart_checkout_path, params: { checkout: { name: "Ada", line1: "1 Ave", city: "London", postal_code: "12345" } }
    post pay_cart_checkout_path
    assert_equal [ { "kind" => "paid", "cart_id" => cart_id } ], published(Screens::Checkout.topic(cart_id)) { perform_enqueued_jobs }

    deliver live_cart_checkout_path, "paid", cart_id: cart_id
    assert_equal [ [ "replace", "checkout_status" ] ], actions
    assert_match(/Redirecting/, response.body)
    deliver live_cart_checkout_path, "declined", cart_id: cart_id
    assert_match(/Payment failed\./, response.body)
  end
end
