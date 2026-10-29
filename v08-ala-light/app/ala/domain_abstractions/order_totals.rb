module DomainAbstractions
  # A bulk order's priced summary: subtotal, its volume tier's discount, then shipping on the subtotal.
  # Keeps the last contents it received. Config: shipping (a CalculateShipping), volume (a callable:
  # subtotal → [percent, label]), shipping_method. In: contents. Out: summary, after every input.
  class OrderTotals
    OUTPUTS = %i[summary].freeze

    def contents(c) = (@lines = c[:lines]; { summary: summary })

    def initialize(shipping:, volume:, shipping_method:)
      @shipping, @volume, @method = shipping, volume, shipping_method
      @lines = []
    end

    private

    def summary
      percent, tier_label = @volume.call(Rules::Pricing.subtotal(@lines))
      Rules::Pricing.summary(@lines, percentage: percent, shipping: @shipping, method: @method).merge(tier_label:)
    end
  end
end
