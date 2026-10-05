require "test_helper"

# Acceptance tests for the portal requirements (R6), ported from the Elixir variants.
class PortalTest < ActionDispatch::IntegrationTest
  def open_portal
    @a = create_product(name: "Bulk Widget", amount: 10_000, stock: 50)
    @b = create_product(name: "Bulk Gadget", amount: 5_000, stock: 3)
    get portal_path
  end

  def po = { order_submission: { po_number: "PO-2026" } }

  test "browse → add at quantity → tier discount → review → submit" do
    open_portal
    assert_select "#portal_products", /Bulk Widget/
    assert_select "#portal_products .stock_#{@b.id}", "Only 3 left!"

    post portal_lines_path, params: { product_id: @a.id, quantity: 6 }
    follow_redirect!
    assert_select "#flash", /Added to order/
    assert_select "#order_lines", /Bulk Widget/
    assert_select "dt", "5% volume discount"
    assert_select "body", /\$570\.00/

    post review_portal_path
    assert_redirected_to portal_step_path(:review)
    follow_redirect!
    assert_select "label", "Purchase order number"

    post submit_portal_path, params: { order_submission: { po_number: "nope" } }
    assert_response :unprocessable_content
    assert_select "body", /must look like PO-1234/

    cart_id = session[:portal_cart_id]
    post submit_portal_path, params: po
    assert_redirected_to portal_step_path(:submitted)
    follow_redirect!
    assert_select "#flash", /Order submitted/
    assert_select "body", /PO-2026/
    assert_select "body", /Reference/
    assert_equal "completed", Cart.find(cart_id).status
    assert_equal "PO-2026", Order.find_by!(cart_id:).po_number
  end

  test "an empty order can't be reviewed" do
    open_portal
    post review_portal_path
    assert_redirected_to portal_path
    follow_redirect!
    assert_select "#flash", /Your order is empty/
  end

  test "repeat add of the same product accumulates quantity; a changed quantity persists and reprices" do
    open_portal
    post portal_lines_path, params: { product_id: @a.id, quantity: 2 }
    post portal_lines_path, params: { product_id: @a.id, quantity: 3 }
    follow_redirect!
    assert_select "#order_lines input[value=?]", "5"
    line = CartItem.find_by!(cart_id: session[:portal_cart_id], product_id: @a.id)

    patch portal_line_path(line), params: { quantity: 1 }
    assert_equal 1, line.reload.quantity
    follow_redirect!
    assert_select "dt", { text: /volume discount/, count: 0 }
  end

  test "browser back from review honours the edge; a forward jump is ignored" do
    open_portal
    post portal_lines_path, params: { product_id: @a.id, quantity: 1 }
    get portal_step_path(:review)
    assert_select "#portal_products"

    post review_portal_path
    get portal_path
    assert_select "#portal_products"
    get portal_step_path(:review)
    assert_select "#portal_products"
  end

  test "removing a line arms the undo banner; undo restores it" do
    open_portal
    post portal_lines_path, params: { product_id: @a.id, quantity: 2 }
    line = CartItem.find_by!(cart_id: session[:portal_cart_id], product_id: @a.id)
    delete portal_line_path(line)
    follow_redirect!
    assert_select "body", /Item removed\./
    assert_select "#order_lines", { text: /Bulk Widget/, count: 0 }

    post portal_undo_path
    follow_redirect!
    assert_select "#order_lines", /Bulk Widget/
  end
end
