module DomainAbstractions
  # What's in a shopper's cart: its stored lines, with quantities and gift wrap. It prices nothing;
  # `contents` hands pricing only what it reads. It holds product ids and asks its `products` port
  # for what they look like. Config: lines (the store), cart_id, links (a lambda of the item id
  # giving the URLs a row's actions post to).
  # Ports in: load, lines (a request answered with { cart_id:, lines: [...] }), bump ({ item_id:,
  # delta: }), set_quantity ({ item_id:, quantity: }), remove, save_for_later, toggle_gift_wrap and
  # line (an item id), receive (a product id, or { product_id:, quantity: }).
  # Ports out: products (a request of product ids), rows (the lines to display), contents
  # ({ lines: [{ quantity, amount }], wrapped_count }), removed (an item id the shopper wants gone),
  # saved (a line set aside: { product_id:, quantity: }), line (a line handed out on request).
  class CartLines
    include Foundation::Ports
    output :products, ProgrammingParadigms::RequestResponse
    output :rows, ProgrammingParadigms::DataFlow
    output :contents, ProgrammingParadigms::DataFlow
    output :removed, ProgrammingParadigms::DataFlow
    output :saved, ProgrammingParadigms::DataFlow, many: true
    output :line, ProgrammingParadigms::DataFlow

    input(:load, ProgrammingParadigms::Event) do
      items = active.to_a
      products = lookup(items)
      emit(:rows, items.map { row(_1, products[_1.product_id]) })
      emit(:contents, lines: items.map { { quantity: _1.quantity, amount: products[_1.product_id][:amount].cents } },
                      wrapped_count: items.count(&:gift_wrapped))
    end

    input(:lines, ProgrammingParadigms::RequestResponse) do |_|
      items = active.to_a
      products = lookup(items)
      { cart_id: @cart_id, lines: items.map { snapshot(_1, products[_1.product_id]) } }
    end

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

    input(:line, ProgrammingParadigms::DataFlow) do |item_id|
      item = active.find(item_id)
      emit(:line, snapshot(item, lookup([ item ])[item.product_id]))
    end

    def initialize(lines:, cart_id:, links: ->(_id) { {} }) = (@lines, @cart_id, @links = lines, cart_id, links)

    private

    def active = @lines.active.where(cart_id: @cart_id)
    def lookup(items) = ask(:products, items.map(&:product_id).uniq)

    def snapshot(item, p)
      { id: item.id, product_id: item.product_id, quantity: item.quantity, amount: p[:amount].cents, name: p[:name],
        description: p[:description], thumbnail: p[:thumbnail] }
    end

    # the neutral shape a displayed line carries, never the record
    def row(item, p)
      { id: item.id, product_id: item.product_id, name: p[:name], thumbnail: p[:thumbnail], amount: p[:amount],
        quantity: item.quantity, line_total: p[:amount] * item.quantity, gift_wrapped: item.gift_wrapped,
        stock: p[:stock], stock_status: p[:stock_status], urls: @links.(item.id) }
    end
  end
end
