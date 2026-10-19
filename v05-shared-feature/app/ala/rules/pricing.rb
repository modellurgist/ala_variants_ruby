module Rules
  # The single-function pricing abstractions: plain calls, because each is an algorithm, not a
  # communicating instance (§7.5). Amounts are integer cents, except a summary's, which are Money.
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

    # The figures every priced summary shows: the discount at a percentage of the subtotal, shipping
    # (a CalculateShipping) by a method on the subtotal, and `extra` cents added to the total.
    def self.summary(lines, percentage:, shipping:, method:, extra: 0)
      m = Foundation::Money
      subtotal = subtotal(lines)
      after_discount, discount = apply_discount(subtotal, percentage)
      shipping_cost = shipping.call(method, subtotal)
      { empty: lines.empty?, item_count: item_count(lines), subtotal: m[subtotal], discount: m[discount],
        shipping_label: shipping.label(method), shipping_cost: m[shipping_cost], total: m[after_discount + extra + shipping_cost] }
    end
  end
end
