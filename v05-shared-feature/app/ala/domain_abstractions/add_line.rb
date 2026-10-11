module DomainAbstractions
  # Puts a product into a stored cart, doing its own I/O through the lines store it is configured with.
  # Config: lines (the store), cart_id. In: add, a product id or { product_id:, quantity: }. Out: added,
  # the stored line.
  class AddLine
    include Foundation::Ports
    output :added, ProgrammingParadigms::DataFlow, many: true

    input(:add, ProgrammingParadigms::DataFlow) do |request|
      product_id, quantity = request.is_a?(Hash) ? request.values_at(:product_id, :quantity) : [ request, 1 ]
      emit(:added, @lines.add(@cart_id, product_id, [ quantity.to_i, 1 ].max))
    end

    def initialize(lines:, cart_id:) = (@lines, @cart_id = lines, cart_id)
  end
end
