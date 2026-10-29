module DomainAbstractions
  # A cart's priced summary. It joins three flows, keeping the last value of each: the cart's contents,
  # the promo discount, and the shipping method, and prices them with the configured rules.
  # Config: shipping (a CalculateShipping), gift_wrap (a CalculateGiftWrapCost, or nil).
  # In: contents, discount, shipping_method. Out: summary, after every input.
  class CartTotals
    OUTPUTS = %i[summary].freeze

    def contents(c) = (@lines, @wrapped = c[:lines], c[:wrapped_count]; changed)
    def discount(discount) = (@discount = discount; changed)
    def shipping_method(method) = (@method = method; changed)

    def initialize(shipping:, gift_wrap: nil)
      @shipping, @gift_wrap = shipping, gift_wrap
      @lines, @wrapped, @discount, @method = [], 0, nil, nil
    end

    private

    def changed = { summary: summary }

    def summary
      m = Foundation::Money
      gift_wrap = @gift_wrap ? @gift_wrap.call(@wrapped) : 0
      Rules::Pricing.summary(@lines, percentage: @discount&.dig(:percentage), shipping: @shipping, method: @method, extras: gift_wrap)
        .merge(promo_code: @discount&.dig(:code), gift_wrap_total: m[gift_wrap], shipping_method: @method,
               shipping_options: @shipping.options.map { |o| o.merge(cost: m[o[:cost]], free_above: o[:free_above] && m[o[:free_above]]) })
    end
  end
end
