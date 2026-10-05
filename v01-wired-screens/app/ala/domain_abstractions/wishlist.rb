module DomainAbstractions
  # Products a shopper wants to remember, in a store of their own. Config: store, cart_id.
  # Ports out: rows, count, ids (the product ids, so a list can mark them), added and dropped (a
  # product id, after a toggle), taken (a product id the shopper wants in the cart).
  class Wishlist
    include Foundation::Ports
    output :rows, ProgrammingParadigms::DataFlow
    output :count, ProgrammingParadigms::DataFlow
    output :ids, ProgrammingParadigms::DataFlow
    output :added, ProgrammingParadigms::DataFlow
    output :dropped, ProgrammingParadigms::DataFlow
    output :taken, ProgrammingParadigms::DataFlow, many: true

    input(:load, ProgrammingParadigms::Event) do
      items = mine.to_a
      emit(:rows, items.map { row(_1) })
      emit(:count, items.size)
      emit(:ids, items.map(&:product_id))
    end

    input(:toggle, ProgrammingParadigms::DataFlow) do |product_id|
      if (item = mine.find_by(product_id:))
        item.destroy!
        emit(:dropped, product_id)
      else
        @store.create!(cart_id: @cart_id, product_id:)
        emit(:added, product_id)
      end
    end

    input(:remove, ProgrammingParadigms::DataFlow) { |product_id| mine.find_by(product_id:)&.destroy! }

    input(:take, ProgrammingParadigms::DataFlow) do |product_id|
      mine.find_by(product_id:)&.destroy! and emit(:taken, product_id)
    end

    def initialize(store:, cart_id:) = (@store, @cart_id = store, cart_id)

    private

    def mine = @store.for_cart(@cart_id)
    def row(item) = { id: item.product_id, name: item.product.name, thumbnail: item.product.thumbnail, amount: Foundation::Money[item.product.amount] }
  end
end
