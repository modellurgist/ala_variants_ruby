require "test_helper"

class CartItemTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  setup do
    @cart = Cart.create!
    @item = @cart.add_product(products(:widget), quantity: 3)
  end

  test "quantity never drops below 1" do
    assert_not @item.update(quantity: 0)
    assert_equal 3, @item.reload.quantity
  end

  test "line total is unit price times quantity" do
    assert_equal 3000, @item.line_total
  end

  test "removing marks the item removed, clears gift wrap, and schedules finalising after the undo window" do
    @item.update!(gift_wrap: true)
    freeze_time do
      assert_enqueued_with(job: FinalizeRemovalJob, at: 5.seconds.from_now) { @item.remove! }
    end
    assert @item.reload.removed_at
    assert_not @item.gift_wrap
    assert_empty @cart.items
  end

  test "a second removal makes the first one final" do
    other = @cart.add_product(products(:gadget))
    @item.remove!
    other.remove!
    assert_not CartItem.exists?(@item.id)
    assert_equal other, @cart.pending_removal
  end

  test "restoring brings the item back into the cart" do
    @item.remove!
    @item.restore!
    assert_equal [ @item ], @cart.items.to_a
  end

  test "save for later and move to cart" do
    @item.save_for_later!
    @item.save_for_later!
    assert_equal [ @item ], @cart.saved_items.to_a
    assert_empty @cart.items
    @item.move_to_cart!
    assert_equal [ @item ], @cart.items.to_a
  end

  test "knows whether its product is wishlisted" do
    assert_not @item.wishlisted?
    @cart.toggle_wishlist(products(:widget))
    assert @item.wishlisted?
  end

  test "broadcasts its storefront row or portal line to its cart" do
    storefront = capture_turbo_stream_broadcasts(@cart) { @item.broadcast_row }
    assert_match "Save for later", storefront.sole.to_html

    portal = Cart.create!(kind: :portal)
    line = portal.add_product(products(:pallet), quantity: 2)
    html = capture_turbo_stream_broadcasts(portal) { line.broadcast_row }.sole.to_html
    assert_match "Quantity of Pallet", html
    assert_no_match "Save for later", html
  end
end
