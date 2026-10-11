require "test_helper"

# The cart's screen lives across requests: a second request finds the first one's composition, and
# a write made elsewhere (another process, a job, the catalogue) is seen through the cart's stamp.
class LongLivedCartTest < ActionDispatch::IntegrationTest
  def open_cart
    get cart_path
    @product = create_product(name: "Widget", amount: 1000, stock: 10)
    @cart_id = session[:cart_id]
  end

  def registry = ProgrammingParadigms::LongLived.named(:cart_screens)

  test "one composition per cart, kept between requests" do
    open_cart
    first = registry.with(@cart_id) { _1 }
    get cart_path
    assert_same first, registry.with(@cart_id) { _1 }
    assert_equal 1, registry.size
  end

  test "a line added by the catalogue is on the cart page, through the stamp" do
    open_cart
    assert_select "#cart_items", count: 1
    assert_no_match(/Widget/, response.body)
    post add_to_cart_product_path(@product)
    get cart_path
    assert_match(/Widget/, response.body)
    assert_select "#cart_tabs", /Items \(1\)/
  end

  test "a write by another process is seen on the next request without a rebuild" do
    open_cart
    item = CartItem.add(@cart_id, @product.id)
    get cart_path
    assert_match(/Widget/, response.body)
    screen = registry.with(@cart_id) { _1 }
    CartItem.where(id: item.id).update_all(quantity: 7)
    get cart_path
    assert_no_match(/tabular-nums">7</, response.body)
    Cart.bump(@cart_id)
    get cart_path
    assert_match(/tabular-nums">7</, response.body)
    assert_same screen, registry.with(@cart_id) { _1 }
  end

  test "each request starts with an empty flash" do
    open_cart
    item = CartItem.add(@cart_id, @product.id)
    patch cart_item_path(item), params: { delta: 1 }, headers: { "Accept" => "text/vnd.turbo-stream.html" }
    post cart_undo_path, headers: { "Accept" => "text/vnd.turbo-stream.html" }
    assert_no_match(/Item restored/, response.body)
    assert_equal({}, registry.with(@cart_id) { _1.flash })
  end
end
