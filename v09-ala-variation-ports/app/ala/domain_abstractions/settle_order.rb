module DomainAbstractions
  # Once a cart is paid: records the order and takes the bought stock, doing its own I/O through the
  # stores it is configured with. Config: orders, lines, products, cart_id. `settle` (the payment
  # reference) answers the new level of each product bought, [{ product_id:, stock: }].
  class SettleOrder
    def settle(_reference)
      @orders.place(@cart_id)
      @lines.active.where(cart_id: @cart_id).filter_map do |line|
        product = @products.decrement_stock(line.product_id, line.quantity)
        { product_id: product.id, stock: product.stock } if product
      end
    end

    def initialize(orders:, lines:, products:, cart_id:) = (@orders, @lines, @products, @cart_id = orders, lines, products, cart_id)
  end
end
