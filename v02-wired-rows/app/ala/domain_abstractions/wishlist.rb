module DomainAbstractions
  # Products a shopper wants to remember, in a store of their own; it asks its `products` port what
  # they look like. Config: store, cart_id, links (a lambda of the product id giving its row's URLs).
  # Ports in: load, toggle, remove and take (a product id). Ports out: products (a request of
  # product ids), rows, count, ids (the product ids, so a list can mark them), added and dropped (a
  # product id, after a toggle), taken (a product id the shopper wants in the cart).
  class Wishlist
    include Foundation::Ports
    output :products, ProgrammingParadigms::RequestResponse
    output :rows, ProgrammingParadigms::DataFlow
    output :count, ProgrammingParadigms::DataFlow
    output :ids, ProgrammingParadigms::DataFlow
    output :added, ProgrammingParadigms::DataFlow
    output :dropped, ProgrammingParadigms::DataFlow
    output :taken, ProgrammingParadigms::DataFlow, many: true

    input(:load, ProgrammingParadigms::Event) do
      items = mine.to_a
      products = ask(:products, items.map(&:product_id))
      emit(:rows, items.map { row(products[_1.product_id]) })
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

    def initialize(store:, cart_id:, links: ->(_id) { {} }) = (@store, @cart_id, @links = store, cart_id, links)

    private

    def mine = @store.for_cart(@cart_id)
    def row(p) = { id: p[:id], name: p[:name], thumbnail: p[:thumbnail], amount: p[:amount], urls: @links.(p[:id]) }
  end
end
