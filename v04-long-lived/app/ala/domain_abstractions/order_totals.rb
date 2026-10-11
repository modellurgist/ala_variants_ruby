module DomainAbstractions
  # A bulk order's priced summary: subtotal, its volume tier's discount, then shipping on the subtotal.
  # Keeps the last contents it received. Config: shipping (a CalculateShipping), volume (a VolumeTier),
  # shipping_method. Port out: summary, after every input.
  class OrderTotals
    include Foundation::Ports
    output :summary, ProgrammingParadigms::DataFlow

    input(:contents, ProgrammingParadigms::DataFlow) { |c| @lines = c[:lines]; emit(:summary, summary) }

    def initialize(shipping:, volume:, shipping_method:)
      @shipping, @volume, @method = shipping, volume, shipping_method
      @lines = []
    end

    private

    def summary
      m = Foundation::Money
      subtotal = Rules::Pricing.subtotal(@lines)
      percent, tier_label = @volume.call(subtotal)
      after_discount, discount = Rules::Pricing.apply_discount(subtotal, percent)
      shipping = @shipping.call(@method, subtotal)
      { empty: @lines.empty?, item_count: Rules::Pricing.item_count(@lines), subtotal: m[subtotal], discount: m[discount], tier_label:,
        shipping_label: @shipping.label(@method), shipping_cost: m[shipping], total: m[after_discount + shipping] }
    end
  end
end
