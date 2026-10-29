module Rules
  # What asks for a product to go into an order: a bare product id (one of it) or { product_id:,
  # quantity: }, read as { product_id:, quantity: } with the quantity never below 1.
  module LineRequest
    def self.call(request)
      product_id, quantity = request.is_a?(Hash) ? request.values_at(:product_id, :quantity) : [ request, 1 ]
      { product_id:, quantity: [ quantity.to_i, 1 ].max }
    end
  end
end
