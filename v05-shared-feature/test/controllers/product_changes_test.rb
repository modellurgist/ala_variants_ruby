require "test_helper"

# A product edited in the catalogue, or its stock taken by another cart's order, reaches the cart and
# checkout compositions already kept for carts that hold it: through the carts' stamps, with the same
# instances re-reading the product, not rebuilt ones.
class ProductChangesTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  setup { FakeGateway.reset }

  def open_cart
    get cart_path
    @cart_id = session[:cart_id]
    @widget = create_product(name: "Widget", amount: 1000, stock: 10)
    CartItem.add(@cart_id, @widget.id, 2)
    get cart_path
    assert_select "#cart_items", /\$10\.00 each/
  end

  def kept(name) = ProgrammingParadigms::LongLived.named(name).with(@cart_id) { _1 }
  def edit_product(product, **attrs) = patch(product_path(product), params: { product: attrs })

  test "a price change shows on a kept cart: the unit price, the line and the summary" do
    open_cart
    screen = kept(:cart_screens)
    edit_product(@widget, amount: 1500)
    get cart_path
    assert_select "#cart_items", /\$15\.00 each/
    assert_select "#cart_items", /\$30\.00/
    assert_select "#cart_summary", /\$30\.00/
    assert_same screen, kept(:cart_screens)
  end

  test "a price change committed during another request's turn shows on the cart's next request" do
    open_cart
    screen = ProgrammingParadigms::LongLived.named(:cart_screens).with(@cart_id) do |kept|
      @widget.update!(amount: 1500)
      kept
    end
    get cart_path
    assert_select "#cart_items", /\$15\.00 each/
    assert_select "#cart_summary", /\$30\.00/
    assert_same screen, kept(:cart_screens)
  end

  test "a name change shows on a kept cart's lines, saved items and wishlist" do
    open_cart
    saved = create_product(name: "Gadget")
    wished = create_product(name: "Gizmo")
    SavedItem.create!(cart_id: @cart_id, product_id: saved.id, quantity: 1)
    WishlistItem.create!(cart_id: @cart_id, product_id: wished.id)
    get cart_path
    screen = kept(:cart_screens)
    edit_product(@widget, name: "Widget Pro")
    edit_product(saved, name: "Gadget Pro")
    edit_product(wished, name: "Gizmo Pro")
    get cart_path
    assert_select "#cart_items", /Widget Pro/
    assert_select "#saved_items", /Gadget Pro/
    assert_select "#wishlist_items", /Gizmo Pro/
    assert_same screen, kept(:cart_screens)
  end

  test "a kept checkout shows and charges the price as it is when the shopper pays" do
    open_cart
    post cart_checkout_path
    patch address_cart_checkout_path, params: { checkout: { name: "Ada", line1: "1 Ave", city: "London", postal_code: "12345" } }
    get cart_checkout_step_path(:payment)
    checkout = kept(:checkout_screens)
    edit_product(@widget, amount: 1500)
    get cart_checkout_step_path(:payment)
    assert_select "form[action=?] button", pay_cart_checkout_path, /Pay \$35\.99/
    post pay_cart_checkout_path
    perform_enqueued_jobs
    assert_equal [ 3000 ], FakeGateway.charges.map { _1[:amount] }
    assert_same checkout, kept(:checkout_screens)
  end

  test "stock taken by another cart's order shows on a kept cart" do
    open_cart
    assert_select "#cart_items", /10 in stock/
    screen = kept(:cart_screens)
    buyer = open_session
    buyer.get cart_path
    CartItem.add(buyer.session[:cart_id], @widget.id, 8)
    buyer.post cart_checkout_path
    buyer.patch address_cart_checkout_path, params: { checkout: { name: "Bo", line1: "2 Ave", city: "Paris", postal_code: "75001" } }
    buyer.post pay_cart_checkout_path
    perform_enqueued_jobs
    assert_equal 2, @widget.reload.stock
    get cart_path
    assert_select "#cart_items", /Only 2 left!/
    assert_same screen, kept(:cart_screens)
  end
end
