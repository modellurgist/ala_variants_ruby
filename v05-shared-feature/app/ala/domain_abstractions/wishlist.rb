module DomainAbstractions
  # Products a shopper wants to remember, as a value: the ids pulled through `items` on load, changed
  # in memory, every change sent out on `changed` for the store the composition wires; it asks its
  # `products` port what they look like. Config: row (a LineRow: the product fields and URLs
  # a wishlisted product's row carries). Ports in: load, show (rows, count and ids again, from memory), toggle, remove and take (a product id). Ports out: items (a request),
  # products (a request of product ids), changed ({ op: :add | :remove, product_id: }), rows, count
  # and ids (after load; rows_changed, count and ids again after a change), added and dropped (a
  # product id, after a toggle), taken (a product id the shopper wants in the cart).
  class Wishlist
    include Foundation::Ports
    output :items, ProgrammingParadigms::RequestResponse
    output :products, ProgrammingParadigms::RequestResponse
    output :changed, ProgrammingParadigms::DataFlow
    output :rows, ProgrammingParadigms::DataFlow
    output :rows_changed, ProgrammingParadigms::DataFlow, many: true
    output :count, ProgrammingParadigms::DataFlow, many: true
    output :ids, ProgrammingParadigms::DataFlow, many: true
    output :added, ProgrammingParadigms::DataFlow
    output :dropped, ProgrammingParadigms::DataFlow
    output :taken, ProgrammingParadigms::DataFlow, many: true

    input(:load, ProgrammingParadigms::Event) do
      @wanted = ask(:items)
      @catalog = ask(:products, @wanted)
      emit(:rows, rows)
      emit(:count, @wanted.size)
      emit(:ids, @wanted)
    end

    input(:show, ProgrammingParadigms::Event) do
      emit(:rows, rows)
      emit(:count, @wanted.size)
      emit(:ids, @wanted)
    end

    input(:toggle, ProgrammingParadigms::DataFlow) do |product_id|
      if @wanted.include?(product_id)
        drop(product_id)
        emit(:dropped, product_id)
      else
        @wanted << product_id
        @catalog.merge!(ask(:products, [ product_id ])) unless @catalog.key?(product_id)
        emit(:changed, op: :add, product_id:)
        emit(:added, product_id)
      end
      changed
    end

    input(:remove, ProgrammingParadigms::DataFlow) do |product_id|
      drop(product_id)
      changed
    end

    input(:take, ProgrammingParadigms::DataFlow) do |product_id|
      drop(product_id)
      emit(:taken, product_id)
      changed
    end

    def initialize(cart_id:, row:) = (@cart_id, @row, @wanted, @catalog = cart_id, row, [], {})

    private

    def drop(product_id)
      @wanted.delete(product_id)
      emit(:changed, op: :remove, product_id:)
    end

    def changed
      emit(:rows_changed, rows)
      emit(:count, @wanted.size)
      emit(:ids, @wanted)
    end

    def rows = @wanted.map { @row.(_1, @catalog.fetch(_1)) }
  end
end
