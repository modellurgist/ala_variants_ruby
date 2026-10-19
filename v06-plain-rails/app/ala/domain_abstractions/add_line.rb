module DomainAbstractions
  # Puts a product into a stored cart, doing its own I/O through the lines store it is configured with.
  # Config: lines (the store), cart_id. In: add, a product id or { product_id:, quantity: }. Out: added,
  # the stored line.
  class AddLine
    OUTPUTS = %i[added].freeze

    def add(request)
      line = Rules::LineRequest.call(request)
      { added: @lines.add(@cart_id, line[:product_id], line[:quantity]) }
    end

    def initialize(lines:, cart_id:) = (@lines, @cart_id = lines, cart_id)
  end
end
