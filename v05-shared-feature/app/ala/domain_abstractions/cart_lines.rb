module DomainAbstractions
  # What's in a shopper's cart, as a value: the lines it was given on load, with quantities and gift
  # wrap, changed in memory and announced. It does no I/O: it pulls its lines and its products
  # through ports, and sends every change out on `changed` for a store the composition wires. It
  # prices nothing; `contents` hands pricing only what it reads. Config: row (a LineRow: the product
  # fields a displayed line carries and the URLs its actions post to).
  # Ports in: load, show (rows and contents again, from memory), lines (a request answered with { cart_id:, lines: [...] }), bump ({ item_id:,
  # delta: }), set_quantity ({ item_id:, quantity: }), remove, save_for_later, toggle_gift_wrap and
  # line (an item id), receive (a product id, or { product_id:, quantity: }), arrived (a stored line's
  # snapshot, after the store added it), product ({ product_id: }, changed elsewhere: asked again).
  # Ports out: items (a request for the stored lines), products (a request of product ids), changed
  # ({ op:, ... } for the store), adding ({ product_id:, quantity: } for the store), rows (every line
  # to display, after load), row_added / row_changed / row_removed (one line, after a change),
  # contents ({ lines: [{ quantity, amount }], wrapped_count }), removed (an item id the shopper
  # wants gone), saved (a line set aside), line (a line handed out on request).
  class CartLines
    include Foundation::Ports
    output :items, ProgrammingParadigms::RequestResponse
    output :products, ProgrammingParadigms::RequestResponse
    output :changed, ProgrammingParadigms::DataFlow
    output :adding, ProgrammingParadigms::DataFlow
    output :rows, ProgrammingParadigms::DataFlow
    output :row_added, ProgrammingParadigms::DataFlow
    output :row_changed, ProgrammingParadigms::DataFlow
    output :row_removed, ProgrammingParadigms::DataFlow
    output :contents, ProgrammingParadigms::DataFlow
    output :removed, ProgrammingParadigms::DataFlow
    output :saved, ProgrammingParadigms::DataFlow, many: true
    output :line, ProgrammingParadigms::DataFlow

    input(:load, ProgrammingParadigms::Event) do
      @held = ask(:items)
      @catalog = ask(:products, @held.map { _1[:product_id] }.uniq)
      emit(:rows, @held.map { row(_1) })
      contents
    end

    # the full list again, from memory: for a page shown by a composition that has lived through changes
    input(:show, ProgrammingParadigms::Event) do
      emit(:rows, @held.map { row(_1) })
      contents
    end

    input(:lines, ProgrammingParadigms::RequestResponse) { |_| { cart_id: @cart_id, lines: @held.map { snapshot(_1) } } }

    input(:bump, ProgrammingParadigms::DataFlow) do |change|
      item = find(change[:item_id])
      item[:quantity] = [ item[:quantity] + change[:delta], 1 ].max
      emit(:changed, op: :quantity, id: item[:id], quantity: item[:quantity])
      emit(:row_changed, row(item))
      contents
    end

    # An absolute quantity, never below 1.
    input(:set_quantity, ProgrammingParadigms::DataFlow) do |change|
      item = find(change[:item_id])
      item[:quantity] = [ change[:quantity].to_i, 1 ].max
      emit(:changed, op: :quantity, id: item[:id], quantity: item[:quantity])
      emit(:row_changed, row(item))
      contents
    end

    # The store keeps a removed line for a while (undo); this value forgets it at once.
    input(:remove, ProgrammingParadigms::DataFlow) do |item_id|
      item = take(item_id)
      emit(:removed, item[:id])
      emit(:row_removed, row(item))
      contents
    end

    input(:save_for_later, ProgrammingParadigms::DataFlow) do |item_id|
      item = take(item_id)
      emit(:changed, op: :remove, id: item[:id])
      emit(:row_removed, row(item))
      emit(:saved, product_id: item[:product_id], quantity: item[:quantity])
      contents
    end

    input(:receive, ProgrammingParadigms::DataFlow) do |request|
      product_id, quantity = request.is_a?(Hash) ? request.values_at(:product_id, :quantity) : [ request, 1 ]
      emit(:adding, product_id:, quantity:)
    end

    input(:arrived, ProgrammingParadigms::DataFlow) do |item|
      @held.reject! { _1[:id] == item[:id] }
      @held << item
      @catalog.merge!(ask(:products, [ item[:product_id] ])) unless @catalog.key?(item[:product_id])
      emit(:row_added, row(item))
      contents
    end

    input(:toggle_gift_wrap, ProgrammingParadigms::DataFlow) do |item_id|
      item = find(item_id)
      item[:gift_wrapped] = !item[:gift_wrapped]
      emit(:changed, op: :gift_wrap, id: item[:id], gift_wrapped: item[:gift_wrapped])
      emit(:row_changed, row(item))
      contents
    end

    input(:line, ProgrammingParadigms::DataFlow) { |item_id| emit(:line, snapshot(find(item_id))) }

    input(:product, ProgrammingParadigms::DataFlow) do |fact|
      next unless @catalog.key?(fact[:product_id])
      @catalog.merge!(ask(:products, [ fact[:product_id] ]))
      @held.select { _1[:product_id] == fact[:product_id] }.each { emit(:row_changed, row(_1)) }
      contents
    end

    def initialize(cart_id:, row: Rules::LineRow.new(fields: [])) = (@cart_id, @row, @held, @catalog = cart_id, row, [], {})

    private

    def find(item_id) = (@held.find { _1[:id] == item_id } or raise ArgumentError, "no line #{item_id}")
    def take(item_id) = find(item_id).tap { |item| @held.delete(item) }
    def product(item) = @catalog.fetch(item[:product_id])

    def contents
      emit(:contents, lines: @held.map { { quantity: _1[:quantity], amount: product(_1)[:amount].cents } },
                      wrapped_count: @held.count { _1[:gift_wrapped] })
    end

    def snapshot(item)
      p = product(item)
      { id: item[:id], product_id: item[:product_id], quantity: item[:quantity], amount: p[:amount].cents, name: p[:name],
        description: p[:description], thumbnail: p[:thumbnail] }
    end

    def row(item)
      p = product(item)
      @row.(item[:id], p, product_id: item[:product_id], quantity: item[:quantity], line_total: p[:amount] * item[:quantity],
                          gift_wrapped: item[:gift_wrapped])
    end
  end
end
