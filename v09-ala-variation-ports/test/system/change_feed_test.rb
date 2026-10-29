require "application_system_test_case"

# A change made in another session reaches an open page through its live feed, end to end.
class ChangeFeedSystemTest < ApplicationSystemTestCase
  setup { @product = create_product(name: "Widget", amount: 1000, stock: 10) }

  def staff_edit(**attrs) = Screens::Catalog.new(cart_id: Cart.create!(status: "open").id).save(id: @product.id, attrs:)

  def subscribed = assert_selector("[data-controller=change-feed][connected]", visible: :all)

  test "a staff stock edit reaches an open cart's badge" do
    visit products_path
    click_on "Add to cart"
    visit cart_path
    assert_text "10 in stock"
    subscribed
    staff_edit(stock: 0)
    assert_text "Out of stock"
  end

  test "a product edit reaches the portal's catalogue as the portal's own row" do
    visit portal_path
    subscribed
    staff_edit(name: "Renamed")
    within("#portal_products") do
      assert_text "Renamed"
      assert_button "Add"
      assert_no_text "Edit"
    end
  end
end
