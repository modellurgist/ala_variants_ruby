require "test_helper"

class FinalizeRemovalJobTest < ActiveJob::TestCase
  setup do
    @cart = Cart.create!
    @item = @cart.add_product(products(:widget))
  end

  test "makes a pending removal permanent and clears the undo banner" do
    @item.remove!
    streams = capture_turbo_stream_broadcasts(@cart) { perform_enqueued_jobs }
    assert_not CartItem.exists?(@item.id)
    assert_equal [ "update", "undo_banner" ], [ streams.sole["action"], streams.sole["target"] ]
  end

  test "leaves an undone removal alone" do
    @item.remove!
    @item.restore!
    assert_no_turbo_stream_broadcasts(@cart) { perform_enqueued_jobs }
    assert CartItem.exists?(@item.id)
  end

  test "leaves a later removal of the same item to its own job" do
    @item.remove!
    @item.restore!
    travel 1.second
    @item.remove!
    FinalizeRemovalJob.perform_now(@item, @item.removed_at - 1.second)
    assert CartItem.exists?(@item.id)
  end

  test "is discarded when the item is already gone" do
    @item.remove!
    @cart.add_product(products(:gadget)).remove!
    assert_nothing_raised { perform_enqueued_jobs }
    assert_empty @cart.cart_items.where(product: products(:widget))
  end
end
