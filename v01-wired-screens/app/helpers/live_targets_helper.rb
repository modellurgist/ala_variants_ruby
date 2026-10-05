# The DOM ids and classes that live updates target. Components render them and screens broadcast to
# them, so both depend on this one module instead of agreeing on a string.
module LiveTargetsHelper
  def product_row_id(product_id) = "product_#{product_id}"
  def stock_marker(product_id) = "stock_#{product_id}"
  def cart_line_id(item_id) = "cart_item_#{item_id}"
end
