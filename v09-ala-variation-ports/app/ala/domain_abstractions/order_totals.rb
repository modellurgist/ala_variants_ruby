module DomainAbstractions
  # A bulk order's priced summary: subtotal, its volume tier's discount, then shipping on the subtotal.
  # Config: shipping (a CalculateShipping), volume (a callable: subtotal → [percent, label]),
  # shipping_method. `summary` takes the order's contents ({ lines: [{ quantity:, amount: }] }).
  class OrderTotals
    def summary(contents)
      lines = contents[:lines]
      percent, tier_label = @volume.call(Rules::Pricing.subtotal(lines))
      Rules::Pricing.summary(lines, percentage: percent, shipping: @shipping, method: @method).merge(tier_label:)
    end

    def initialize(shipping:, volume:, shipping_method:) = (@shipping, @volume, @method = shipping, volume, shipping_method)
  end
end
