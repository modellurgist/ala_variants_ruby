module DomainAbstractions
  # Lines a shopper set aside for later, in a store of their own. Config: store, cart_id.
  # Ports out: rows, count (after load or a change), moved ({ product_id:, quantity: } the shopper
  # wants back in the cart).
  class SavedItems
    include Foundation::Ports
    output :rows, ProgrammingParadigms::DataFlow
    output :count, ProgrammingParadigms::DataFlow
    output :moved, ProgrammingParadigms::DataFlow, many: true

    input(:load, ProgrammingParadigms::Event) do
      items = mine.to_a
      emit(:rows, items.map { row(_1) })
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

    def initialize(store:, cart_id:) = (@store, @cart_id = store, cart_id)

    private

    def mine = @store.for_cart(@cart_id)
    def row(item) = { id: item.id, name: item.product.name, thumbnail: item.product.thumbnail, amount: Foundation::Money[item.product.amount] }
  end
end
