require "test_helper"

class ProductsTest < ActionDispatch::IntegrationTest
  test "lists all products with stock and an add-to-cart button" do
    product = create_product(name: "Widget", stock: 3)
    get products_path
    assert_response :success
    assert_select "h1", "All Products"
    assert_select "#product_#{product.id}", /Widget/
    assert_select ".stock_#{product.id}", "Only 3 left!"
    assert_select "form[action=?]", add_to_cart_product_path(product)
  end

  test "shows one product" do
    product = create_product(name: "Gadget")
    get product_path(product)
    assert_response :success
    assert_select "h1", "Show Product"
    assert_select "#product_#{product.id}", /Gadget/
  end

  test "creates a product, flashes, and broadcasts it to open lists" do
    get new_product_path
    assert_select "form[id^=form_product]"

    assert_turbo_stream_broadcasts(Screens::Catalog::STREAM, count: 2) do
      post products_path, params: { product: { name: "New", description: "d", amount: 42, stock: 42, thumbnail: "t.png" } }
    end
    assert_redirected_to products_path
    follow_redirect!
    assert_select "#flash", /Product created successfully/
    assert_select "#products", /New/
  end

  test "an invalid product shows the form again with errors" do
    post products_path, params: { product: { name: "", amount: "" } }
    assert_response :unprocessable_content
    assert_select "form[id^=form_product]", /can't be blank/
    assert_equal 0, Product.count
  end

  test "validates live, answering with the form as a Turbo Stream" do
    post validate_products_path, params: { product: { name: "", amount: 5 } }, headers: { "Accept" => "text/vnd.turbo-stream.html" }
    assert_response :success
    assert_match(/turbo-stream action="replace" target="form_product"/, response.body)
    assert_match(/can&#39;t be blank/, response.body)
  end

  test "updates a product from its edit form" do
    product = create_product(name: "Old")
    get edit_product_path(product)
    assert_select "form[id^=form_product] input[value=?]", "Old"

    patch product_path(product), params: { product: { name: "Renamed" } }
    assert_redirected_to product_path(product)
    follow_redirect!
    assert_select "#flash", /Product updated successfully/
    assert_equal "Renamed", product.reload.name
  end

  test "deletes a product" do
    product = create_product
    delete product_path(product)
    assert_redirected_to products_path
    assert_nil Product.find_by(id: product.id)
  end

  test "add to cart persists a line in the session's cart and flashes" do
    product = create_product
    post add_to_cart_product_path(product)
    assert_redirected_to products_path
    follow_redirect!
    assert_select "#flash", /Added to cart/
    line = CartItem.find_by(cart_id: session[:cart_id], product_id: product.id)
    assert_equal 1, line.quantity

    post add_to_cart_product_path(product)
    assert_equal 2, line.reload.quantity
  end
end
