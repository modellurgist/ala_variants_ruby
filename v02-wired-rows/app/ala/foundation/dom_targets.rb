module Foundation
  # The DOM ids and classes live updates target. Elements render them and screens broadcast to them,
  # so both depend on this one module instead of agreeing on a string (R5). Declared as a view helper
  # by ApplicationController.
  module DomTargets
    module_function

    def product_row_id(product_id) = "product_#{product_id}"
    def stock_marker(product_id) = "stock_#{product_id}"
    def cart_line_id(item_id) = "cart_item_#{item_id}"
  end
end
