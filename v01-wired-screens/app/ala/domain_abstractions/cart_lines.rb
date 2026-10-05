module DomainAbstractions
  # What's in a shopper's cart: its stored lines, with quantities and gift wrap. It prices nothing;
  # `contents` hands pricing only what it reads. Config: lines (the store), cart_id, stock_rule.
  # Ports out: rows (the lines to display), contents ({ lines: [{quantity, amount}], wrapped_count }),
  # removed (an item id the shopper wants gone), saved (a line set aside: { product_id:, quantity: }),
  # line (a line handed out on request, for the wishlist). Ports in, besides the changes: lines, a
  # request answered with { cart_id:, lines: [...] }, for whoever needs the stored lines themselves.
  class CartLines
    include Foundation::Ports
    output :rows, ProgrammingParadigms::DataFlow
    output :contents, ProgrammingParadigms::DataFlow
    output :removed, ProgrammingParadigms::DataFlow
    output :saved, ProgrammingParadigms::DataFlow, many: true
    output :line, ProgrammingParadigms::DataFlow

    input(:load, ProgrammingParadigms::Event) do
      items = active.to_a
      emit(:rows, items.map { row(_1) })
      emit(:contents, lines: items.map { { quantity: _1.quantity, amount: _1.product.amount } }, wrapped_count: items.count(&:gift_wrapped))
    end

    input(:lines, ProgrammingParadigms::RequestResponse) { |_| { cart_id: @cart_id, lines: active.map { snapshot(_1) } } }

    input(:bump, ProgrammingParadigms::DataFlow) do |change|
      active.find(change[:item_id]).then { _1.update!(quantity: [ _1.quantity + change[:delta], 1 ].max) }
    end

    # An absolute quantity, never below 1.
    input(:set_quantity, ProgrammingParadigms::DataFlow) do |change|
      active.find(change[:item_id]).update!(quantity: [ change[:quantity].to_i, 1 ].max)
    end

    input(:remove, ProgrammingParadigms::DataFlow) { |item_id| emit(:removed, active.find(item_id).id) }

    input(:save_for_later, ProgrammingParadigms::DataFlow) do |item_id|
      item = active.find(item_id)
      item.destroy!
      emit(:saved, product_id: item.product_id, quantity: item.quantity)
    end

    input(:receive, ProgrammingParadigms::DataFlow) do |request|
      product_id, quantity = request.is_a?(Hash) ? request.values_at(:product_id, :quantity) : [ request, 1 ]
      @lines.add(@cart_id, product_id, quantity)
    end

    input(:toggle_gift_wrap, ProgrammingParadigms::DataFlow) { |item_id| active.find(item_id).then { _1.update!(gift_wrapped: !_1.gift_wrapped) } }
    input(:line, ProgrammingParadigms::DataFlow) { |item_id| emit(:line, snapshot(active.find(item_id))) }

    def initialize(lines:, cart_id:, stock_rule:) = (@lines, @cart_id, @stock_rule = lines, cart_id, stock_rule)

    private

    def active = @lines.active.where(cart_id: @cart_id)

    def snapshot(item)
      p = item.product
      { id: item.id, product_id: p.id, quantity: item.quantity, amount: p.amount, name: p.name, description: p.description, thumbnail: p.thumbnail }
    end

    # the neutral shape a displayed line carries, never the record
    def row(item)
      p = item.product
      { id: item.id, product_id: p.id, name: p.name, thumbnail: p.thumbnail, amount: Foundation::Money[p.amount],
        quantity: item.quantity, line_total: Foundation::Money[p.amount * item.quantity], gift_wrapped: item.gift_wrapped,
        stock: p.stock, stock_status: @stock_rule.call(p.stock) }
    end
  end
end
