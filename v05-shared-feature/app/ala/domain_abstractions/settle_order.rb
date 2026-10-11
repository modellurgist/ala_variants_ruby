module DomainAbstractions
  # Once a cart is paid: records the order, takes the bought stock, and announces each new level,
  # doing its own I/O through the stores it is configured with. Config: orders, lines, products,
  # cart_id. In: settle (the payment reference). Out: stock_changed ({ product_id:, stock: }, one
  # per product bought).
  class SettleOrder
    include Foundation::Ports
    output :stock_changed, ProgrammingParadigms::DataFlow, many: true

    input(:settle, ProgrammingParadigms::DataFlow) do |_reference|
      @orders.place(@cart_id)
      @lines.active.where(cart_id: @cart_id).each do |line|
        product = @products.decrement_stock(line.product_id, line.quantity)
        emit(:stock_changed, product_id: product.id, stock: product.stock) if product
      end
    end

    def initialize(orders:, lines:, products:, cart_id:) = (@orders, @lines, @products, @cart_id = orders, lines, products, cart_id)
  end
end
