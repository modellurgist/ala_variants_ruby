require "test_helper"

# Outside change through the ChangeFeed paradigm (R2.5, R2.6, R3.14, R6.8, R8.1): a change publishes a fact
# on its topic, a page's feed posts the fact back to the page, and the page's composition answers
# with what changed there. The browser's half (receiving and posting) is in the system tests.
class ChangeFeedUpdatesTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  TURBO = { "Accept" => "text/vnd.turbo-stream.html" }.freeze

  setup { FakeGateway.reset }

  def facts(topic, &) = capture_turbo_stream_broadcasts(topic, &).map { [ _1["action"], _1["kind"], JSON.parse(_1["fact"]) ] }
  def post_fact(path, kind, fact) = post(path, params: { kind:, fact: fact.to_json }, headers: TURBO)
  def streams = response.body.scan(/<turbo-stream ([^>]*)>/).map { |(attrs)| attrs.scan(/(\w+)="([^"]*)"/).to_h.slice("action", "target", "method") }

  def open_cart
    get cart_path
    @cart_id = session[:cart_id]
    @widget = create_product(name: "Widget", amount: 1000, stock: 10)
    @gadget = create_product(name: "Gadget", amount: 2500, stock: 8)
    @item = CartItem.add(@cart_id, @widget.id, 2)
    SavedItem.create!(cart_id: @cart_id, product_id: @gadget.id)
    WishlistItem.create!(cart_id: @cart_id, product_id: @gadget.id)
    get cart_path
  end

  test "a product saved at /products publishes a fact keyed by its id, never its row" do
    product = create_product(name: "Widget")
    sent = facts(Screens::Store::CATALOG_TOPIC) { patch product_path(product), params: { product: { name: "Gizmo" } } }
    assert_equal [ [ "change_feed", "product", { "product_id" => product.id } ] ], sent
  end

  test "a paid order publishes each new stock level on the catalogue and the outcome on the cart's own topic" do
    open_cart
    post cart_checkout_path
    patch address_cart_checkout_path, params: { checkout: { name: "Ada", line1: "1 Ave", city: "London", postal_code: "12345" } }
    post pay_cart_checkout_path
    outcome = nil
    stock = facts(Screens::Store::CATALOG_TOPIC) { outcome = facts(Screens::Checkout.topic(@cart_id)) { perform_enqueued_jobs } }
    assert_equal [ [ "change_feed", "stock", { "product_id" => @widget.id, "stock" => 8 } ] ], stock
    assert_equal [ [ "change_feed", "outcome", { "cart_id" => @cart_id, "step" => "complete" } ] ], outcome
  end

  test "the product list places its feed and answers a fact with the list drawn again from the table" do
    product = create_product(name: "Widget", stock: 9)
    get products_path
    assert_select "[data-controller=change-feed][data-change-feed-url-value=?][data-change-feed-kinds-value=?]", live_products_path, '["product","stock"]'
    product.update!(name: "Gizmo")
    post_fact live_products_path, :product, product_id: product.id
    assert_equal [ { "action" => "update", "target" => "products", "method" => "morph" } ], streams
    assert_includes response.body, "Gizmo"
    product.update!(stock: 2)
    post_fact live_products_path, :stock, product_id: product.id, stock: 2
    assert_includes response.body, "Only 2 left!"
  end

  test "a product's own page shows its product again" do
    product = create_product(name: "Widget")
    get product_path(product)
    product.update!(name: "Gizmo")
    post_fact live_row_product_path(product), :product, product_id: product.id
    assert_equal [ { "action" => "update", "target" => Screens::Catalog::SHOWN, "method" => "morph" } ], streams
    assert_includes response.body, "Gizmo"
  end

  test "a stock change elsewhere patches the open cart's line" do
    open_cart
    Product.decrement_stock(@widget.id, 7)
    post_fact live_cart_path, :stock, product_id: @widget.id, stock: 3
    assert_includes streams, { "action" => "replace", "target" => "cart_item_#{@item.id}" }
    assert_select "turbo-stream[target=?] .stock_#{@widget.id}", "cart_item_#{@item.id}", "Only 3 left!"
  end

  # Before 2026-10-21 a staff edit reached product lists only: an open cart's badge and prices waited for a reload.
  test "a staff edit at /products reaches an open cart: its line, the summary, saved items and the wishlist" do
    open_cart
    widget = facts(Screens::Store::CATALOG_TOPIC) { patch product_path(@widget), params: { product: { amount: 1500, stock: 1 } } }
    gadget = facts(Screens::Store::CATALOG_TOPIC) { patch product_path(@gadget), params: { product: { amount: 3000 } } }
    post_fact live_cart_path, *widget.first.drop(1)
    assert_select "turbo-stream[target=?] .stock_#{@widget.id}", "cart_item_#{@item.id}", "Only 1 left!"
    assert_select "turbo-stream[target=?]", "cart_item_#{@item.id}", /\$30\.00/
    assert_select "turbo-stream[target=cart_summary]", /\$30\.00/
    post_fact live_cart_path, *gadget.first.drop(1)
    assert_select "turbo-stream[target=saved_items]", /\$30\.00/
    assert_select "turbo-stream[target=wishlist_items]", /\$30\.00/
  end

  test "the waiting checkout page is answered with the outcome its payment reached" do
    open_cart
    post cart_checkout_path
    patch address_cart_checkout_path, params: { checkout: { name: "Ada", line1: "1 Ave", city: "London", postal_code: "12345" } }
    post pay_cart_checkout_path
    get cart_checkout_step_path(:payment)
    assert_select "[data-controller=change-feed][data-change-feed-url-value=?]", live_cart_checkout_path
    perform_enqueued_jobs
    post_fact live_cart_checkout_path, :outcome, cart_id: @cart_id, step: :complete
    assert_equal [ { "action" => "replace", "target" => Screens::Checkout::STATUS_TARGET } ], streams
    assert_includes response.body, "Redirecting…"
  end

  test "the portal answers a stock change with its order lines and its catalogue drawn again" do
    widget = create_product(name: "Bulk Widget", amount: 10_000, stock: 50)
    get portal_path
    post portal_lines_path, params: { product_id: widget.id, quantity: 6 }
    Product.decrement_stock(widget.id, 47)
    post_fact live_portal_path, :stock, product_id: widget.id, stock: 3
    assert_equal [ "order_lines", "portal_products" ], streams.map { _1["target"] }
    assert_select "turbo-stream[target=order_lines] .stock_#{widget.id}", "Only 3 left!"
    assert_select "turbo-stream[target=portal_products] .stock_#{widget.id}", "Only 3 left!"
    widget.update!(name: "Bulk Gizmo")
    post_fact live_portal_path, :product, product_id: widget.id
    assert_select "turbo-stream[target=order_lines]", /Bulk Gizmo/
  end
end
