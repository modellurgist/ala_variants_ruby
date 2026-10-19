module DomainAbstractions
  # Lines a shopper set aside for later, as a value: given its stored lines on load, changed in
  # memory, every change sent out on `changed` for the store the composition wires; it asks the
  # products it holds what they look like. Config: cart_id, held (a Rules::HeldProducts whose links
  # take the saved item's id). In: load (the stored lines), reload (them again, after a stash: the
  # store gives the new line its id), stash ({ product_id:, quantity: }), move_to_cart (an id).
  # Out: changed ({ op:, ... }), rows and count (after load), rows_changed and count (after a
  # change), moved ({ product_id:, quantity: } the shopper wants back in the cart).
  class SavedItems
    OUTPUTS = %i[changed rows rows_changed count moved].freeze

    def load(items)
      @held.load(items)
      { rows: @held.rows, count: items.size }
    end

    # The stored lines again, after a write gave a new line its id: the pane redraws.
    def reload(items) = (load(items); { rows_changed: @held.rows, count: items.size })

    # Saving is idempotent by product.
    def stash(line) = { changed: { op: :stash, product_id: line[:product_id], quantity: line[:quantity] } }

    def move_to_cart(id)
      item = @held.take(id)
      { changed: { op: :remove, id: }, moved: item.slice(:product_id, :quantity), rows_changed: @held.rows, count: @held.entries.size }
    end

    def initialize(cart_id:, held:) = (@cart_id, @held = cart_id, held)
  end
end
