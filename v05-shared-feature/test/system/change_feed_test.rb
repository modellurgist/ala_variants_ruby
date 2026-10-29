require "application_system_test_case"

# A change made in another session reaches an open page without a reload: the fact over the stream,
# posted back by the page's feed, answered by the page's composition.
class ChangeFeedSystemTest < ApplicationSystemTestCase
  def edit_elsewhere(product, field, value)
    using_session(:staff) do
      visit edit_product_path(product)
      fill_in field, with: value
      click_on "Save Product"
      assert_text "Product updated successfully"
    end
  end

  test "a product saved in another session updates an open product list" do
    widget = create_product(name: "Widget")
    visit products_path
    assert_selector "turbo-cable-stream-source[connected]", visible: :all
    edit_elsewhere(widget, "Name", "Gizmo")
    assert_selector "#products", text: "Gizmo"
  end

  test "a stock edit at /products reaches an open cart's line" do
    widget = create_product(name: "Widget", stock: 10)
    visit products_path
    click_on "Add to cart"
    visit cart_path
    assert_selector "turbo-cable-stream-source[connected]", visible: :all
    assert_selector ".stock_#{widget.id}", text: "10 in stock"
    edit_elsewhere(widget, "Stock", "2")
    assert_selector ".stock_#{widget.id}", text: "Only 2 left!"
  end
end
