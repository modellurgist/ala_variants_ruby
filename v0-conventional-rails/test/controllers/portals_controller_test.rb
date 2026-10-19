require "test_helper"

class PortalsControllerTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  def portal_cart
    Cart.find(session[:portal_cart_id])
  end

  def add_line(product, quantity)
    post portal_lines_path, params: { product_id: product.id, quantity: }, headers: turbo_stream
    portal_cart.items.find_by!(product:)
  end

  test "the order step lists the catalog with stock status and a quantity input; out of stock can't be added" do
    get portal_path
    assert_select "li[aria-current=step]", /Order/
    assert_select "#portal_product_#{products(:pallet).id}" do
      assert_select "span", "In stock"
      assert_select "input[type=number][name=quantity][min='1']"
      assert_select "input[type=submit][value='Add to order']:not([disabled])"
    end
    assert_select "#portal_product_#{products(:sold_out).id} input[type=submit][disabled]"
  end

  test "adding sets the requested quantity, at least 1, and repeat adds accumulate" do
    line = add_line(products(:pallet), 3)
    assert_equal 3, line.quantity
    assert_turbo_stream action: "append", target: "portal_lines"
    assert_stream_text "flash", /Added to order/
    assert_equal 5, add_line(products(:pallet), 2).quantity
    assert_equal 1, add_line(products(:widget), 0).quantity
  end

  test "lines show name, stock status, quantity, and line total; changing quantity persists and reprices" do
    line = add_line(products(:pallet), 2)
    get portal_path
    assert_select "#cart_item_#{line.id}" do
      assert_select "span", "Pallet"
      assert_select "span", "In stock"
      assert_select "input[type=number][value='2'][min='1']"
      assert_select "span", "$200.00"
    end
    patch portal_line_path(line), params: { quantity: 6 }, headers: turbo_stream
    assert_equal 6, line.reload.quantity
    assert_turbo_stream action: "replace", target: "cart_item_#{line.id}"
    assert_turbo_stream action: "update", target: "portal_summary" do
      assert_select "dt", "5% volume discount"
      assert_select "dd", "−$30.00"
    end
    patch portal_line_path(line), params: { quantity: 0 }, headers: turbo_stream
    assert_equal 1, line.reload.quantity
  end

  test "volume pricing reprices across tier boundaries" do
    line = add_line(products(:pallet), 20)
    assert_turbo_stream action: "update", target: "portal_summary" do
      assert_select "dt", "10% volume discount"
    end
    patch portal_line_path(line), params: { quantity: 4 }, headers: turbo_stream
    assert_turbo_stream action: "update", target: "portal_summary" do
      assert_select "dt", text: /volume discount/, count: 0
    end
  end

  test "removing a line arms the undo banner; undo restores it; the elapsed window makes it final" do
    line = add_line(products(:pallet), 2)
    delete portal_line_path(line), headers: turbo_stream
    assert_turbo_stream action: "remove", target: "cart_item_#{line.id}"
    assert_turbo_stream action: "update", target: "undo_banner" do
      assert_select "form[action=?]", portal_undo_path
    end
    get portal_path
    assert_select "#undo_banner button", "Undo"

    post portal_undo_path, headers: turbo_stream
    assert_turbo_stream action: "append", target: "portal_lines"
    assert_stream_text "flash", /Item restored/
    assert_equal [ line ], portal_cart.items.to_a

    delete portal_line_path(line), headers: turbo_stream
    perform_enqueued_jobs
    assert_not CartItem.exists?(line.id)
    post portal_undo_path, headers: turbo_stream
    assert_no_turbo_stream action: "append"
  end

  test "shipping methods as in the storefront; no promo or gift wrap" do
    add_line(products(:widget), 1)
    get portal_path
    assert_select "input[type=radio][name=shipping_method]", 3
    assert_select "input[name=code]", count: 0
    assert_select "button", text: "Gift wrap", count: 0
    patch portal_shipping_method_path, params: { shipping_method: "express" }, headers: turbo_stream
    assert_equal "express", portal_cart.shipping_method
    assert_turbo_stream action: "update", target: "portal_summary" do
      assert_select "dt", "Shipping (Express (2–3 days))"
    end
  end

  test "review with an empty order flashes and stays; a forward jump to Submitted is ignored" do
    get review_portal_path
    assert_redirected_to portal_path
    assert_equal "Your order is empty", flash[:alert]
    get submitted_portal_path
    assert_redirected_to portal_path
  end

  test "review shows the total and a purchase order form, with Edit lines going back" do
    add_line(products(:pallet), 1)
    get review_portal_path
    assert_select "h1", "Review order · $100.00"
    assert_select "li[data-step-state=done]", /Order/
    assert_select "form[data-controller=live-validation] input[name='order[po_number]']"
    assert_select "a[href=?]", portal_path, text: "Edit lines"
  end

  test "the purchase order number is live-validated" do
    get portal_path
    post validate_portal_path, params: { order: { po_number: "" } }, headers: turbo_stream
    assert_turbo_stream(action: "update", target: "order_errors") { assert_select "li", "Po number can't be blank" }
    post validate_portal_path, params: { order: { po_number: "PO-12" } }, headers: turbo_stream
    assert_turbo_stream(action: "update", target: "order_errors") { assert_select "li", "Po number must look like PO-1234" }
    post validate_portal_path, params: { order: { po_number: "PO-1234" } }, headers: turbo_stream
    assert_turbo_stream(action: "update", target: "order_errors") { assert_select "li", count: 0 }
  end

  test "submitting with a valid PO completes the draft, creates the order, and lands on Submitted" do
    add_line(products(:pallet), 2)
    draft = portal_cart
    post portal_order_path, params: { order: { po_number: "PO-98765" } }
    order = Order.last
    assert_redirected_to submitted_portal_path
    assert_equal "Order submitted", flash[:notice]
    assert draft.reload.completed?
    assert_equal [ "PO-98765", 2 ], [ order.po_number, order.order_items.sole.quantity ]
    follow_redirect!
    assert_select "strong", order.reference
    assert_select "li[aria-current=step]", /Submitted/

    get portal_path
    assert_not_equal draft, portal_cart
  end

  test "submitting with an invalid PO re-renders review with the error" do
    add_line(products(:pallet), 2)
    assert_no_difference("Order.count") { post portal_order_path, params: { order: { po_number: "PO-1" } } }
    assert_response :unprocessable_entity
    assert_select "#order_errors li", "Po number must look like PO-1234"
    assert portal_cart.open?
  end

  test "submitting an empty order flashes" do
    get portal_path
    post portal_order_path, params: { order: { po_number: "PO-1234" } }
    assert_redirected_to portal_path
    assert_equal "Your order is empty", flash[:alert]
  end
end
