module DomainAbstractions
  # Products a shopper wants to remember, as a value: the ids given on load, changed in memory,
  # every change sent out on `changed` for the store the composition wires; it asks the products it
  # holds what they look like. Config: cart_id, held (a Rules::HeldProducts whose entries are product
  # ids, each its own id). In: load (the stored ids), toggle, remove and take (a product id). Out: changed
  # ({ op: :add | :remove, product_id: }), rows, count and ids (after load; rows_changed, count and
  # ids again after a change), added and dropped (a product id, after a toggle), taken (a product id
  # the shopper wants in the cart).
  class Wishlist
    OUTPUTS = %i[changed rows rows_changed count ids added dropped taken].freeze

    def load(ids)
      @held.load(ids)
      { rows: @held.rows, count: ids.size, ids: @held.entries }
    end

    def toggle(product_id)
      return drop(product_id).merge(dropped: product_id).merge(changed_rows) if @held.entries.include?(product_id)
      @held.add(product_id)
      { changed: { op: :add, product_id: }, added: product_id }.merge(changed_rows)
    end

    def remove(product_id) = drop(product_id).merge(changed_rows)
    def take(product_id) = drop(product_id).merge(taken: product_id).merge(changed_rows)

    def initialize(cart_id:, held:) = (@cart_id, @held = cart_id, held)

    private

    def drop(product_id)
      @held.take(product_id) if @held.entries.include?(product_id)
      { changed: { op: :remove, product_id: } }
    end

    def changed_rows = { rows_changed: @held.rows, count: @held.entries.size, ids: @held.entries }
  end
end
