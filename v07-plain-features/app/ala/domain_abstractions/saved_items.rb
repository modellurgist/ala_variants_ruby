module DomainAbstractions
  # Lines a shopper set aside for later, as a value: given its stored lines on load, changed in
  # memory, every change sent out on `changed` for the store the composition wires; it asks the
  # configured `products` lambda what the products look like. Config: products, links (a lambda of
  # the saved item's id giving its row's URLs). In: load (the stored lines), reload (them again, after a stash: the
  # store gives the new line its id), stash ({ product_id:, quantity: }), move_to_cart (an id).
  # Out: changed ({ op:, ... }), rows and count (after load), rows_changed and count (after a
  # change), moved ({ product_id:, quantity: } the shopper wants back in the cart).
  class SavedItems
    OUTPUTS = %i[changed rows rows_changed count moved].freeze

    def load(items)
      @held = items
      @catalog = @products.(@held.map { _1[:product_id] }.uniq)
      { rows: rows, count: @held.size }
    end

    # The stored lines again, after a write gave a new line its id: the pane redraws.
    def reload(items) = (load(items); { rows_changed: rows, count: @held.size })

    # Saving is idempotent by product.
    def stash(line) = { changed: { op: :stash, product_id: line[:product_id], quantity: line[:quantity] } }

    def move_to_cart(id)
      item = @held.find { _1[:id] == id } or raise ArgumentError, "no saved item #{id}"
      @held.delete(item)
      { changed: { op: :remove, id: }, moved: { product_id: item[:product_id], quantity: item[:quantity] }, rows_changed: rows, count: @held.size }
    end

    def initialize(cart_id:, products:, links: ->(_id) { {} }) = (@cart_id, @products, @links, @held, @catalog = cart_id, products, links, [], {})

    private

    def rows = @held.map { |i| p = @catalog.fetch(i[:product_id]); { id: i[:id], name: p[:name], thumbnail: p[:thumbnail], amount: p[:amount], urls: @links.(i[:id]) } }
  end
end
