module DomainAbstractions
  # Products a shopper wants to remember, as a value: the ids given on load, changed in memory,
  # every change sent out on `changed` for the store the composition wires; it asks the configured
  # `products` lambda what they look like. Config: products, links (a lambda of the product id giving
  # its row's URLs). In: load (the stored ids), toggle, remove and take (a product id). Out: changed
  # ({ op: :add | :remove, product_id: }), rows, count and ids (after load; rows_changed, count and
  # ids again after a change), added and dropped (a product id, after a toggle), taken (a product id
  # the shopper wants in the cart).
  class Wishlist
    OUTPUTS = %i[changed rows rows_changed count ids added dropped taken].freeze

    def load(ids)
      @wanted = ids
      @catalog = @products.(@wanted)
      { rows: rows, count: @wanted.size, ids: @wanted }
    end

    def toggle(product_id)
      return drop(product_id).merge(dropped: product_id).merge(changed_rows) if @wanted.include?(product_id)
      @wanted << product_id
      @catalog.merge!(@products.([ product_id ])) unless @catalog.key?(product_id)
      { changed: { op: :add, product_id: }, added: product_id }.merge(changed_rows)
    end

    def remove(product_id) = drop(product_id).merge(changed_rows)
    def take(product_id) = drop(product_id).merge(taken: product_id).merge(changed_rows)

    def initialize(cart_id:, products:, links: ->(_id) { {} }) = (@cart_id, @products, @links, @wanted, @catalog = cart_id, products, links, [], {})

    private

    def drop(product_id)
      @wanted.delete(product_id)
      { changed: { op: :remove, product_id: } }
    end

    def changed_rows = { rows_changed: rows, count: @wanted.size, ids: @wanted }

    def rows = @wanted.map { |id| p = @catalog.fetch(id); { id: id, name: p[:name], thumbnail: p[:thumbnail], amount: p[:amount], urls: @links.(id) } }
  end
end
