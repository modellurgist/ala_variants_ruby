module DomainAbstractions
  # The single-function pricing abstractions: plain calls, because each is an algorithm, not a
  # communicating instance (§7.5). All amounts are integer cents.
  module Pricing
    # Σ amount × quantity over lines of { quantity:, amount: }.
    def self.subtotal(lines) = lines.sum { _1[:amount] * _1[:quantity] }

    def self.item_count(lines) = lines.sum { _1[:quantity] }

    # Returns [after_discount, discount] for a percentage, or no change for nil or 0.
    def self.apply_discount(subtotal, percentage)
      return [ subtotal, 0 ] if percentage.nil? || percentage.zero?
      discount = subtotal * percentage / 100
      [ [ subtotal - discount, 0 ].max, discount ]
    end
  end
end
