module Foundation
  # The DOM ids and classes stream patches and live answers target. Elements render them and screens
  # patch them, so both depend on this one module instead of agreeing on a string (R5). Declared as a
  # view helper by ApplicationController.
  module DomTargets
    module_function

    def product_row_id(product_id) = "product_#{product_id}"
    def stock_marker(product_id) = "stock_#{product_id}"
    def cart_line_id(item_id) = "cart_item_#{item_id}"
    def items_pane_id = "cart_items"
    def empty_note_id = "cart_empty"
    def saved_pane_id = "saved_items"
    def wishlist_pane_id = "wishlist_items"
    def tabs_id = "cart_tabs"
    def summary_id = "cart_summary"
    def shipping_selector_id = "cart_shipping"
    def promo_form_id = "cart_promo"
    def checkout_button_id = "cart_checkout"
    def undo_id = "cart_undo"
    def flash_id = "flash"
    def order_lines_id = "order_lines"
    def portal_products_id = "portal_products"
  end
end
