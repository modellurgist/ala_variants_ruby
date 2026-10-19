module DomainAbstractions
  # What's in a shopper's cart, as a value: the lines it was given on load, with quantities and gift
  # wrap, changed in memory and announced. It does no I/O: the composition hands it its stored lines,
  # it asks its configured rows what products look like, and every change it decides goes out on
  # `changed` for a store the composition wires. It prices nothing; `contents` hands pricing only what
  # it reads. Config: cart_id, rows (a LineRow, with the URLs a line's actions post to).
  # In: load (the stored lines), lines (answers { cart_id:, lines: [...] }), bump ({ item_id:,
  # delta: }), set_quantity ({ item_id:, quantity: }), remove, save_for_later, toggle_gift_wrap and
  # line (an item id), receive (a product id, or { product_id:, quantity: }), arrived (a stored line's
  # snapshot, after the store added it).
  # Out: changed ({ op:, ... } for the store), adding ({ product_id:, quantity: } for the store), rows
  # (every line to display, after load), row_added / row_changed / row_removed (one line, after a
  # change), contents ({ lines: [{ quantity, amount }], wrapped_count }), removed (an item id the
  # shopper wants gone), saved (a line set aside), line (a line handed out on request).
  class CartLines
    OUTPUTS = %i[changed adding rows row_added row_changed row_removed contents removed saved line].freeze

    def load(items)
      @held = items
      @rows.fill(@held.map { _1[:product_id] })
      { rows: @held.map { row(_1) }, contents: contents }
    end

    def lines = { cart_id: @cart_id, lines: @held.map { snapshot(_1) } }

    def bump(change)
      item = find(change[:item_id])
      item[:quantity] = [ item[:quantity] + change[:delta], 1 ].max
      { changed: { op: :quantity, id: item[:id], quantity: item[:quantity] }, row_changed: row(item), contents: contents }
    end

    # An absolute quantity, never below 1.
    def set_quantity(change)
      item = find(change[:item_id])
      item[:quantity] = [ change[:quantity].to_i, 1 ].max
      { changed: { op: :quantity, id: item[:id], quantity: item[:quantity] }, row_changed: row(item), contents: contents }
    end

    # The store keeps a removed line for a while (undo); this value forgets it at once.
    def remove(item_id)
      item = take(item_id)
      { removed: item[:id], row_removed: row(item), contents: contents }
    end

    def save_for_later(item_id)
      # ala:accept clone -- the mirror of SavedItems#move_to_cart: each list removes its own line and hands on the same { product_id:, quantity: }
      item = take(item_id)
      { changed: { op: :remove, id: item[:id] }, row_removed: row(item), saved: { product_id: item[:product_id], quantity: item[:quantity] }, contents: contents }
    end

    def receive(request) = { adding: Rules::LineRequest.call(request) }

    def arrived(item)
      @held.reject! { _1[:id] == item[:id] }
      @held << item
      { row_added: row(item), contents: contents }
    end

    def toggle_gift_wrap(item_id)
      item = find(item_id)
      item[:gift_wrapped] = !item[:gift_wrapped]
      { changed: { op: :gift_wrap, id: item[:id], gift_wrapped: item[:gift_wrapped] }, row_changed: row(item), contents: contents }
    end

    def line(item_id) = { line: snapshot(find(item_id)) }

    def initialize(cart_id:, rows:) = (@cart_id, @rows, @held = cart_id, rows, [])

    private

    def find(item_id) = (@held.find { _1[:id] == item_id } or raise ArgumentError, "no line #{item_id}")
    def take(item_id) = find(item_id).tap { |item| @held.delete(item) }
    def product(item) = @rows.product(item[:product_id])

    def contents
      { lines: @held.map { { quantity: _1[:quantity], amount: product(_1)[:amount].cents } }, wrapped_count: @held.count { _1[:gift_wrapped] } }
    end

    def snapshot(item)
      p = product(item)
      { id: item[:id], product_id: item[:product_id], quantity: item[:quantity], amount: p[:amount].cents, name: p[:name],
        description: p[:description], thumbnail: p[:thumbnail] }
    end

    def row(item) = @rows.(item.merge(line_total: product(item)[:amount] * item[:quantity]))
  end
end
