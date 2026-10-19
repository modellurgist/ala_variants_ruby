require "test_helper"

class CartTest < ActiveSupport::TestCase
  setup { @cart = Cart.create! }

  test "a new cart is open, a storefront cart, ships standard, and lives in Postgres" do
    assert @cart.open?
    assert @cart.storefront?
    assert_equal "standard", @cart.shipping_method
    assert_equal "PostgreSQL", Cart.connection.adapter_name
  end

  test "status is open, completed, or abandoned" do
    assert_equal %w[open completed abandoned], Cart.statuses.keys
    @cart.abandoned!
    assert_not Cart.open.exists?(@cart.id)
  end

  test "rejects an unknown shipping method" do
    @cart.shipping_method = "teleport"
    assert_not @cart.valid?
  end

  test "adding a product creates a line, and adding it again increments that line" do
    line = @cart.add_product(products(:widget))
    assert_equal 1, line.quantity
    again = @cart.add_product(products(:widget))
    assert_equal line, again
    assert_equal 2, again.quantity
    assert_equal 1, @cart.items.count
  end

  test "adding a product that was saved for later moves it back and increments it" do
    line = @cart.add_product(products(:widget))
    line.save_for_later!
    @cart.add_product(products(:widget))
    assert_equal [ 2, false ], [ line.reload.quantity, line.saved_for_later ]
  end

  test "adding a product whose removal is pending starts a fresh line" do
    line = @cart.add_product(products(:widget), quantity: 4)
    line.update!(gift_wrap: true)
    line.remove!
    @cart.add_product(products(:widget))
    assert_equal [ 1, nil, false ], [ line.reload.quantity, line.removed_at, line.gift_wrap ]
  end

  test "items exclude saved and removed lines" do
    kept = @cart.add_product(products(:widget))
    @cart.add_product(products(:gadget)).save_for_later!
    @cart.add_product(products(:pallet)).remove!
    assert_equal [ kept ], @cart.items.to_a
    assert_equal [ products(:gadget) ], @cart.saved_items.map(&:product)
    assert_equal products(:pallet), @cart.pending_removal.product
  end

  test "a valid promo code is stored normalised; an invalid one leaves the cart unchanged" do
    assert @cart.apply_promo_code(" save10 ")
    assert_equal "SAVE10", @cart.reload.promo_code
    assert_not @cart.apply_promo_code("BOGUS")
    assert_equal "SAVE10", @cart.reload.promo_code
  end

  test "toggling the wishlist adds then removes the product" do
    added = @cart.toggle_wishlist(products(:widget))
    assert_not added.destroyed?
    assert @cart.wishlisted?(products(:widget))
    removed = @cart.toggle_wishlist(products(:widget))
    assert removed.destroyed?
    assert_not @cart.wishlisted?(products(:widget))
  end

  test "knows when any item is short of stock" do
    @cart.add_product(products(:gadget), quantity: 3)
    assert_not @cart.out_of_stock_items?
    @cart.add_product(products(:gadget))
    assert @cart.out_of_stock_items?
  end

  test "placing a storefront order snapshots the lines, decrements stock, and completes the cart" do
    @cart.add_product(products(:widget), quantity: 2)
    order = @cart.place_order(decrement_stock: true)
    assert order.persisted?
    assert_equal 2000 + 599, order.total_cents
    assert_equal [ [ "Widget", 2, 1000 ] ], order.order_items.map { [ _1.name, _1.quantity, _1.unit_amount ] }
    assert_equal 8, products(:widget).reload.stock
    assert @cart.reload.completed?
  end

  test "a portal order needs a valid purchase order number and leaves stock alone" do
    portal = Cart.create!(kind: :portal)
    portal.add_product(products(:pallet), quantity: 2)
    invalid = portal.place_order(po_number: "nope")
    assert_not invalid.persisted?
    assert portal.reload.open?

    order = portal.place_order(po_number: "PO-1234")
    assert order.persisted?
    assert_equal "PO-1234", order.po_number
    assert portal.reload.completed?
    assert_equal 50, products(:pallet).reload.stock
  end

  test "the undo window comes from configuration" do
    assert_equal 5.seconds, Cart.undo_window
    Rails.configuration.x.store.undo_window_seconds = 1
    assert_equal 1.second, Cart.undo_window
  ensure
    Rails.configuration.x.store.undo_window_seconds = 5
  end
end
