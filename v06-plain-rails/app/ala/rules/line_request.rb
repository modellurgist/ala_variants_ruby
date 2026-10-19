module Rules
  # A request to put a product in a list of lines: a product id alone means one; a quantity is at least 1.
  module LineRequest
    def self.call(request)
      product_id, quantity = request.is_a?(Hash) ? request.values_at(:product_id, :quantity) : [ request, 1 ]
      { product_id:, quantity: [ quantity.to_i, 1 ].max }
    end
  end
end
