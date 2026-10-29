require "application_system_test_case"

# Changes made elsewhere, through the screens that make them, reaching pages already open.
class ChangeFeedSystemTest < ApplicationSystemTestCase
  def elsewhere = Cart.create!(status: "open").id
  def staff_save(id, attrs) = Screens::Catalog.new(cart_id: elsewhere).save(id:, attrs:)

  def purchase_elsewhere(product, quantity)
    cart_id = elsewhere
    CartItem.add(cart_id, product.id, quantity)
    Screens::Checkout.new(cart_id:).charge(line_items: [ { unit_amount: product.amount, quantity:, currency: "usd" } ], cart_id:)
  end

  def listening = assert_selector("[data-controller=change-feed][connected]", visible: :all)

  test "a purchase elsewhere updates an open cart's stock, and the cart keeps its tab" do
    product = create_product(name: "Widget", stock: 10)
    visit products_path
    click_on "Add to cart"
    assert_text "Added to cart"
    visit cart_path
    listening
    click_on "Saved (0)"
    purchase_elsewhere(product, 7)
    assert_selector ".stock_#{product.id}", text: "Only 3 left!", visible: :all
    assert_selector "[data-tabs-target=pane][data-name=saved]:not([hidden])"
  end

  test "a staff edit of stock at /products reaches an open cart" do
    product = create_product(name: "Widget", stock: 10)
    visit products_path
    click_on "Add to cart"
    visit cart_path
    listening
    staff_save(product.id, { stock: 0 })
    assert_selector ".stock_#{product.id}", text: "Out of stock"
  end

  test "a product saved elsewhere joins an open list, and the open form keeps what was typed" do
    create_product(name: "Widget")
    visit products_path
    listening
    click_on "New Product"
    within("turbo-frame#modal") { fill_in "Description", with: "Half typed" }
    staff_save(nil, { name: "Gizmo", amount: 500, stock: 5, description: "d", thumbnail: "g.png" })
    assert_selector "#products", text: "Gizmo"
    assert_field "Description", with: "Half typed"
  end

  test "an open portal follows a purchase, a staff edit and a new product" do
    product = create_product(name: "Pallet", amount: 10_000, stock: 50)
    visit portal_path
    listening
    purchase_elsewhere(product, 10)
    assert_selector ".stock_#{product.id}", text: "40 in stock"
    staff_save(product.id, { stock: 2 })
    assert_selector ".stock_#{product.id}", text: "Only 2 left!"
    assert_no_button "Delete"
    assert_field "quantity"
    staff_save(nil, { name: "Crate", amount: 900, stock: 9, description: "d", thumbnail: "c.png" })
    assert_text "Crate"
  end
end
