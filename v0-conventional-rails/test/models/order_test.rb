require "test_helper"

class OrderTest < ActiveSupport::TestCase
  test "portal orders need a PO- number with at least four digits" do
    portal = Cart.create!(kind: :portal)
    { nil => "can't be blank", "PO-123" => "must look like PO-1234", "po-1234" => "must look like PO-1234", "PO-12a4" => "must look like PO-1234" }.each do |po, error|
      order = Order.new(cart: portal, po_number: po, total_cents: 0)
      assert_not order.valid?
      assert_equal [ error ], order.errors[:po_number]
    end
    assert Order.new(cart: portal, po_number: "PO-123456", total_cents: 0).valid?
  end

  test "storefront orders need no purchase order" do
    assert Order.new(cart: Cart.create!, total_cents: 0).valid?
  end

  test "reference" do
    assert_equal "GD-000042", Order.new(id: 42).reference
  end
end
