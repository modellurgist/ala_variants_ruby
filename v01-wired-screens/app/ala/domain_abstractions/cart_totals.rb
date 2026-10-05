module DomainAbstractions
  # A cart's priced summary. It joins three flows, keeping the last value of each: the cart's contents,
  # the promo discount, and the shipping method, and prices them with the configured rules.
  # Config: shipping (a CalculateShipping), gift_wrap (a CalculateGiftWrapCost, or nil).
  # Port out: summary, after every input.
  class CartTotals
    include Foundation::Ports
    output :summary, ProgrammingParadigms::DataFlow

    input(:contents, ProgrammingParadigms::DataFlow) { |c| @lines, @wrapped = c[:lines], c[:wrapped_count]; changed }
    input(:discount, ProgrammingParadigms::DataFlow) { |discount| @discount = discount; changed }
    input(:shipping_method, ProgrammingParadigms::DataFlow) { |method| @method = method; changed }

    def initialize(shipping:, gift_wrap: nil)
      @shipping, @gift_wrap = shipping, gift_wrap
      @lines, @wrapped, @discount, @method = [], 0, nil, nil
    end

    private

    def changed = emit(:summary, summary)

    def summary
      m = Foundation::Money
      subtotal = Pricing.subtotal(@lines)
      after_discount, discount = Pricing.apply_discount(subtotal, @discount&.dig(:percentage))
      gift_wrap = @gift_wrap ? @gift_wrap.call(@wrapped) : 0
      shipping = @shipping.call(@method, subtotal)
      { empty: @lines.empty?, item_count: Pricing.item_count(@lines), subtotal: m[subtotal], discount: m[discount],
        promo_code: @discount&.dig(:code), gift_wrap_total: m[gift_wrap], shipping_method: @method,
        shipping_label: @shipping.label(@method), shipping_cost: m[shipping],
        shipping_options: @shipping.options.map { |o| o.merge(cost: m[o[:cost]], free_above: o[:free_above] && m[o[:free_above]]) },
        total: m[after_discount + gift_wrap + shipping] }
    end
  end
end
