module DomainAbstractions
  # Lines a shopper set aside for later, in a store of their own; it asks its `products` port what
  # the products look like. Config: store, cart_id, links (a lambda of the saved item's id giving
  # its row's URLs). Ports in: load, stash ({ product_id:, quantity: }), move_to_cart (an id).
  # Ports out: products (a request of product ids), rows, count (after load), moved
  # ({ product_id:, quantity: } the shopper wants back in the cart).
  class SavedItems
    include Foundation::Ports
    output :products, ProgrammingParadigms::RequestResponse
    output :rows, ProgrammingParadigms::DataFlow
    output :count, ProgrammingParadigms::DataFlow
    output :moved, ProgrammingParadigms::DataFlow, many: true

    input(:load, ProgrammingParadigms::Event) do
      items = mine.to_a
      products = ask(:products, items.map(&:product_id))
      emit(:rows, items.map { row(_1, products[_1.product_id]) })
      emit(:count, items.size)
    end

    # Saving is idempotent by product.
    input(:stash, ProgrammingParadigms::DataFlow) do |line|
      @store.find_or_create_by!(cart_id: @cart_id, product_id: line[:product_id]) { _1.quantity = line[:quantity] }
    end

    input(:move_to_cart, ProgrammingParadigms::DataFlow) do |id|
      item = mine.find(id)
      item.destroy!
      emit(:moved, product_id: item.product_id, quantity: item.quantity)
    end

    def initialize(store:, cart_id:, links: ->(_id) { {} }) = (@store, @cart_id, @links = store, cart_id, links)

    private

    def mine = @store.for_cart(@cart_id)
    def row(item, p) = { id: item.id, name: p[:name], thumbnail: p[:thumbnail], amount: p[:amount], urls: @links.(item.id) }
  end
end
