module DomainAbstractions
  # Whether every line of { product_id:, quantity: } is covered by stock levels { product_id => stock }.
  module CheckStock
    def self.call(lines, levels) = lines.all? { levels.fetch(_1[:product_id], 0) >= _1[:quantity] }
  end
end
