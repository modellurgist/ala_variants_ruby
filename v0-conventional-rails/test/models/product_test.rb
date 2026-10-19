require "test_helper"

class ProductTest < ActiveSupport::TestCase
  test "requires a name and an amount" do
    product = Product.new
    assert_not product.valid?
    assert_includes product.errors[:name], "can't be blank"
    assert_includes product.errors[:amount], "can't be blank"
  end

  test "rejects negative amounts and stock" do
    product = Product.new(name: "X", amount: -1, stock: -2)
    assert_not product.valid?
    assert product.errors[:amount].any?
    assert product.errors[:stock].any?
  end

  test "stock status is in stock, low stock at 5 or fewer, or out of stock" do
    assert_equal :in_stock, Product.new(stock: 6).stock_status
    assert_equal :low_stock, Product.new(stock: 5).stock_status
    assert_equal :low_stock, Product.new(stock: 1).stock_status
    assert_equal :out_of_stock, Product.new(stock: 0).stock_status
  end

  test "the low-stock threshold comes from configuration" do
    Rails.configuration.x.store.low_stock_threshold = 10
    assert_equal :low_stock, Product.new(stock: 8).stock_status
  ensure
    Rails.configuration.x.store.low_stock_threshold = 5
  end

  test "creating a product appends it to every product list and portal catalog" do
    assert_turbo_stream_broadcasts("products", count: 1) do
      assert_turbo_stream_broadcasts("portal_products", count: 1) do
        Product.create!(name: "New", amount: 100)
      end
    end
  end

  test "updating a product replaces its row in every product list and portal catalog" do
    product = products(:widget)
    streams = capture_turbo_stream_broadcasts("products") { product.update!(name: "Renamed") }
    assert_equal "replace", streams.sole["action"]
    assert_equal "product_#{product.id}", streams.sole["target"]
    assert_match "Renamed", streams.sole.to_html

    portal = capture_turbo_stream_broadcasts("portal_products") { product.update!(stock: 0) }
    assert_equal "portal_product_#{product.id}", portal.sole["target"]
    assert_match "Out of stock", portal.sole.to_html
  end

  test "a stock change updates the product's row in every open cart and portal draft, but not completed carts" do
    product = products(:gadget)
    storefront = Cart.create!
    storefront.add_product(product)
    portal = Cart.create!(kind: :portal)
    portal.add_product(product, quantity: 2)
    completed = Cart.create!(status: :completed)
    completed.add_product(product)

    assert_turbo_stream_broadcasts(storefront, count: 1) do
      assert_turbo_stream_broadcasts(portal, count: 1) do
        assert_no_turbo_stream_broadcasts(completed) { product.decrement_stock!(3) }
      end
    end
    assert_equal 0, product.reload.stock
    assert_match "Out of stock", capture_turbo_stream_broadcasts(storefront) { product.touch }.sole.to_html
  end

  test "destroying a product removes it from every list, along with its cart lines" do
    product = products(:widget)
    Cart.create!.add_product(product)
    portal = nil
    list = capture_turbo_stream_broadcasts("products") do
      portal = capture_turbo_stream_broadcasts("portal_products") { product.destroy! }
    end
    assert_equal [ "remove", "product_#{product.id}" ], [ list.sole["action"], list.sole["target"] ]
    assert_equal [ "remove", "portal_product_#{product.id}" ], [ portal.sole["action"], portal.sole["target"] ]
    assert_not CartItem.exists?(product_id: product.id)
  end
end
