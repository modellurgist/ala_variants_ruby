module DomainAbstractions
  # Lines a shopper set aside for later, as a value: pulled through `items` on load, changed in
  # memory, every change sent out on `changed` for the store the composition wires; it asks its
  # `products` port what the products look like. Config: row (a LineRow: the product fields and
  # URLs a saved item's row carries). Ports in: load, show (rows and count again, from memory), stash ({ product_id:, quantity: }), move_to_cart (an id),
  # product ({ product_id: }, changed elsewhere: asked again).
  # Ports out: items (a request), products (a request of product ids), changed ({ op:, ... }), rows
  # and count (after load, and again after a change as rows_changed / count), moved ({ product_id:,
  # quantity: } the shopper wants back in the cart).
  class SavedItems
    include Foundation::Ports
    output :items, ProgrammingParadigms::RequestResponse
    output :products, ProgrammingParadigms::RequestResponse
    output :changed, ProgrammingParadigms::DataFlow
    output :rows, ProgrammingParadigms::DataFlow
    output :rows_changed, ProgrammingParadigms::DataFlow, many: true
    output :count, ProgrammingParadigms::DataFlow, many: true
    output :moved, ProgrammingParadigms::DataFlow, many: true

    input(:load, ProgrammingParadigms::Event) do
      @held = ask(:items)
      @catalog = ask(:products, @held.map { _1[:product_id] }.uniq)
      emit(:rows, rows)
      emit(:count, @held.size)
    end

    input(:show, ProgrammingParadigms::Event) do
      emit(:rows, rows)
      emit(:count, @held.size)
    end

    # Saving is idempotent by product. The store gives the new line its id, so the value asks for
    # its lines again before it redraws.
    input(:stash, ProgrammingParadigms::DataFlow) do |line|
      emit(:changed, op: :stash, product_id: line[:product_id], quantity: line[:quantity])
      @held = ask(:items)
      @catalog.merge!(ask(:products, [ line[:product_id] ])) unless @catalog.key?(line[:product_id])
      changed
    end

    input(:move_to_cart, ProgrammingParadigms::DataFlow) do |id|
      item = @held.find { _1[:id] == id } or raise ArgumentError, "no saved item #{id}"
      @held.delete(item)
      emit(:changed, op: :remove, id:)
      emit(:moved, product_id: item[:product_id], quantity: item[:quantity])
      changed
    end

    input(:product, ProgrammingParadigms::DataFlow) do |fact|
      next unless @held.any? { _1[:product_id] == fact[:product_id] }
      @catalog.merge!(ask(:products, [ fact[:product_id] ]))
      changed
    end

    def initialize(cart_id:, row:) = (@cart_id, @row, @held, @catalog = cart_id, row, [], {})

    private

    def changed
      emit(:rows_changed, rows)
      emit(:count, @held.size)
    end

    def rows = @held.map { @row.(_1[:id], @catalog.fetch(_1[:product_id])) }
  end
end
