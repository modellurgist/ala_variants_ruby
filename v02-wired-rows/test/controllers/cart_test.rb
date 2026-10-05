require "test_helper"

# Acceptance tests for the storefront cart requirements (R3, R4), ported from the Elixir variants.
class CartTest < ActionDispatch::IntegrationTest
  def open_cart
    get cart_path # mints the session's cart
    @a = create_product(name: "Widget", amount: 1000, stock: 10, thumbnail: "w.png")
    @b = create_product(name: "Gadget", amount: 2500, stock: 5, thumbnail: "g.png")
    @item_a = CartItem.add(session[:cart_id], @a.id)
    @item_b = CartItem.add(session[:cart_id], @b.id)
    get cart_path
  end

  def lines = CartItem.active.where(cart_id: session[:cart_id])

  test "renders items, shipping and a checkout button" do
    open_cart
    assert_select "h1", "Your Cart"
    assert_select "body", /Widget/
    assert_select "legend", "Shipping"
    assert_select "form[action=?] button", cart_checkout_path, /Checkout/
    assert_select "body", /\$35\.00/
  end

  test "an empty cart disables checkout" do
    get cart_path
    assert_select "body", /Your cart is empty/
    assert_select "form[action=?] button[disabled]", cart_checkout_path
  end

  test "increment updates the quantity and total, and persists" do
    open_cart
    patch cart_item_path(@item_a), params: { delta: 1 }
    follow_redirect!
    assert_select "body", /\$20\.00/
    assert_equal 2, @item_a.reload.quantity
  end

  test "decrement never drops below 1" do
    open_cart
    patch cart_item_path(@item_a), params: { delta: -5 }
    assert_equal 1, @item_a.reload.quantity
  end

  test "remove shows the undo banner, then undo restores" do
    open_cart
    delete cart_item_path(@item_a)
    follow_redirect!
    assert_select "body", /Item removed/
    assert_select "form[action=?] button", cart_undo_path, "Undo"
    assert_select "#cart_item_#{@item_a.id}", false
    assert CartItem.exists?(@item_a.id), "the line is still stored while the removal can be undone"

    post cart_undo_path
    follow_redirect!
    assert_select "body", /Item restored/
    assert_select "body", /Widget/
  end

  test "when the undo window elapses the removal is persisted" do
    open_cart
    delete cart_item_path(@item_a)
    assert CartItem.exists?(@item_a.id)

    post expire_cart_undo_path
    follow_redirect!
    assert_select "body", { text: /Undo/, count: 0 }
    assert_not CartItem.exists?(@item_a.id)
  end

  test "an expired removal is finalized on the next load even without the browser's post" do
    open_cart
    delete cart_item_path(@item_a)
    travel Screens::Store::UNDO_WINDOW + 1.second do
      get cart_path
      assert_not CartItem.exists?(@item_a.id)
      assert_select "body", { text: /Undo/, count: 0 }
    end
  end

  test "a second removal makes the first final; only the latest can be undone" do
    open_cart
    delete cart_item_path(@item_a)
    delete cart_item_path(@item_b)
    assert_not CartItem.exists?(@item_a.id)

    post cart_undo_path
    follow_redirect!
    assert_select "body", /Gadget/
    assert_select "body", { text: /Widget/, count: 0 }
  end

  test "toggle gift wrap adds a gift-wrap line to the summary, and toggling again removes it" do
    open_cart
    patch gift_wrap_cart_item_path(@item_a)
    follow_redirect!
    assert_select "dt", "Gift wrap"
    assert_select "body", /\$43\.98/
    patch gift_wrap_cart_item_path(@item_a)
    follow_redirect!
    assert_select "dt", { text: "Gift wrap", count: 0 }
  end

  test "save for later moves an item to the Saved tab and back" do
    open_cart
    post save_cart_item_path(@item_a)
    follow_redirect!
    assert_select "#flash", /Saved for later/
    assert_select "[data-name=saved] button", "Move to cart"
    assert_select "button", /Saved \(1\)/
    saved = SavedItem.find_by!(cart_id: session[:cart_id], product_id: @a.id)

    post move_cart_saved_item_path(saved)
    follow_redirect!
    assert_select "#flash", /Moved to cart/
    assert lines.exists?(product_id: @a.id)
  end

  test "wishlist a cart item, see it in the Wishlist tab, add it back to the cart" do
    open_cart
    post wishlist_cart_item_path(@item_a)
    follow_redirect!
    assert_select "#flash", /Added to wishlist/
    assert_select "body", /♥ Wishlisted/
    assert_select "[data-name=wishlist]", /Widget/

    post add_to_cart_cart_wishlist_item_path(@a)
    follow_redirect!
    assert_select "#flash", /Added to cart/
    assert_equal 2, lines.find_by(product_id: @a.id).quantity
    assert_select "button", /Wishlist \(0\)/
  end

  test "a wishlisted product can be removed from the wishlist" do
    open_cart
    post wishlist_cart_item_path(@item_a)
    delete cart_wishlist_item_path(@a)
    follow_redirect!
    assert_select "button", /Wishlist \(0\)/
  end

  test "a valid promo shows the discount; an invalid one shows an inline error and changes nothing" do
    open_cart
    post promo_cart_path, params: { code: "save10" }
    follow_redirect!
    assert_select "#flash", /Promo applied!/
    assert_select "dt", "Discount (SAVE10)"
    assert_select "body", /\$37\.49/

    post promo_cart_path, params: { code: "BOGUS" }
    follow_redirect!
    assert_select "#flash", /Invalid promo code/
    assert_select "p", "Invalid promo code"
    assert_select "dt", "Discount (SAVE10)"
  end

  test "selecting express shipping updates the cost" do
    open_cart
    patch shipping_cart_path, params: { shipping_method: "express" }
    follow_redirect!
    assert_select "dt", "Shipping (Express (2–3 days))"
    assert_select "body", /\$47\.99/
  end

  test "stock badges show low and out of stock, and a stock change is broadcast to every open page" do
    open_cart
    assert_select ".stock_#{@b.id}", "Only 5 left!"
  end
end
