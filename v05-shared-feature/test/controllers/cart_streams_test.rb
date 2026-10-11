require "test_helper"

# A change on the cart answers a Turbo request with the patches its outputs made, never a redirect.
class CartStreamsTest < ActionDispatch::IntegrationTest
  TURBO = { "Accept" => "text/vnd.turbo-stream.html" }.freeze

  def open_cart
    get cart_path
    @product = create_product(name: "Widget", amount: 1000, stock: 10)
    @item = CartItem.add(session[:cart_id], @product.id)
  end

  def actions = response.body.scan(/<turbo-stream action="(\w+)" target="([^"]+)"/)

  test "a quantity change patches the line, the summary, the tabs and the flash" do
    open_cart
    patch cart_item_path(@item), params: { delta: 1 }, headers: TURBO
    assert_response :success
    assert_equal "text/vnd.turbo-stream.html", response.media_type
    assert_includes actions, [ "replace", "cart_item_#{@item.id}" ]
    assert_includes actions, [ "update", "cart_summary" ]
    assert_includes actions, [ "update", "cart_tabs" ]
    assert_includes actions, [ "replace", "flash" ]
    assert_match(/\$25\.99/, response.body)
    assert_equal 2, @item.reload.quantity
  end

  test "a removal removes the line and offers undo; undo appends it back" do
    open_cart
    delete cart_item_path(@item), headers: TURBO
    assert_includes actions, [ "remove", "cart_item_#{@item.id}" ]
    assert_includes actions, [ "update", "cart_undo" ]
    assert_match(/Item removed/, response.body)
    post cart_undo_path, headers: TURBO
    assert_includes actions, [ "update", "cart_undo" ]
    assert_match(/Item restored/, response.body)
    assert_nil @item.reload.removed_at
  end

  test "saving for later removes the line and redraws the saved pane; moving back appends a line" do
    open_cart
    post save_cart_item_path(@item), headers: TURBO
    assert_includes actions, [ "remove", "cart_item_#{@item.id}" ]
    assert_includes actions, [ "update", "saved_items" ]
    saved = SavedItem.for_cart(session[:cart_id]).first
    post move_cart_saved_item_path(saved), headers: TURBO
    assert_includes actions, [ "append", "cart_items" ]
    assert_includes actions, [ "update", "saved_items" ]
    assert_equal 1, CartItem.active.where(cart_id: session[:cart_id]).count
  end

  test "a plain request still lands on the cart" do
    open_cart
    patch cart_item_path(@item), params: { delta: 1 }
    assert_redirected_to cart_path
  end
end
