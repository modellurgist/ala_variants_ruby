require "test_helper"

class ProductsControllerTest < ActionDispatch::IntegrationTest
  setup { @product = products(:widget) }

  test "index lists every product with name, description, price, thumbnail, and stock" do
    get products_path
    assert_response :success
    assert_select "turbo-cable-stream-source"
    assert_select "#product_#{@product.id}" do
      assert_select "h2", "Widget"
      assert_select "p", "A fine widget"
      assert_select "img[src=?]", @product.thumbnail
      assert_select "span", "$10.00"
      assert_select "span", "Stock: 10"
      assert_select "span", "In stock"
    end
    assert_select "#product_#{products(:gadget).id} span", "Low stock (3 left)"
    assert_select "#product_#{products(:sold_out).id} span", "Out of stock"
  end

  test "shows one product" do
    get product_path(@product)
    assert_response :success
    assert_select "h2", "Widget"
    assert_select "a[href=?][data-turbo-frame=modal]", show_edit_product_path(@product)
  end

  test "new, edit, and show/edit render the form in the modal frame" do
    [ new_product_path, edit_product_path(@product), show_edit_product_path(@product) ].each do |path|
      get path, headers: { "Turbo-Frame" => "modal" }
      assert_response :success
      assert_select "turbo-frame#modal form[data-controller=live-validation]"
    end
    get show_edit_product_path(@product)
    assert_select "turbo-frame#modal", count: 1
    assert_select "a[href=?]", product_path(@product), text: "Cancel"
  end

  test "creating a product closes the modal and flashes" do
    assert_difference("Product.count") do
      post products_path, params: { product: { name: "Gizmo", amount: 500, stock: 2 } }, headers: turbo_stream
    end
    assert_turbo_stream action: "update", target: "modal"
    assert_turbo_stream action: "update", target: "flash" do
      assert_select "div", "Product created successfully"
    end
  end

  test "creating without turbo redirects to the list" do
    post products_path, params: { product: { name: "Gizmo", amount: 500 } }
    assert_redirected_to products_path
    assert_equal "Product created successfully", flash[:notice]
  end

  test "an invalid product re-renders the form with errors" do
    assert_no_difference("Product.count") do
      post products_path, params: { product: { name: "", amount: "" } }, headers: turbo_stream
    end
    assert_response :unprocessable_entity
    assert_select "#product_errors li", "Name can't be blank"
    assert_select "#product_errors li", "Amount can't be blank"
  end

  test "updating a product closes the modal and flashes" do
    patch product_path(@product), params: { product: { name: "Widget Pro" } }, headers: turbo_stream
    assert_turbo_stream action: "update", target: "modal"
    assert_equal "Widget Pro", @product.reload.name
  end

  test "updating without turbo redirects to the product, and invalid input re-renders" do
    patch product_path(@product), params: { product: { amount: 1200 } }
    assert_redirected_to product_path(@product)
    patch product_path(@product), params: { product: { name: "" } }
    assert_response :unprocessable_entity
  end

  test "destroying a product" do
    assert_difference("Product.count", -1) { delete product_path(@product) }
    assert_redirected_to products_path
  end

  test "live validation of a new product reports errors as the shopper types" do
    post validate_products_path, params: { product: { name: "", amount: "5" } }, headers: turbo_stream
    assert_turbo_stream action: "update", target: "product_errors" do
      assert_select "li", "Name can't be blank"
    end
    post validate_products_path, params: { product: { name: "Ok", amount: "5" } }, headers: turbo_stream
    assert_turbo_stream action: "update", target: "product_errors" do
      assert_select "li", count: 0
    end
  end

  test "live validation of an existing product" do
    post validate_product_path(@product), params: { product: { amount: "" } }, headers: turbo_stream
    assert_turbo_stream action: "update", target: "product_errors" do
      assert_select "li", "Amount can't be blank"
    end
    assert_equal 1000, @product.reload.amount
  end
end
