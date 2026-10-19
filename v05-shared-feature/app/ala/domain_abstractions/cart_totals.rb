module DomainAbstractions
  # A cart's priced summary. It joins three flows, keeping the last value of each: the cart's contents,
  # the promo discount, and the shipping method, and prices them with the configured rules.
  # Config: shipping (a CalculateShipping), gift_wrap (a CalculateGiftWrapCost, or nil).
  # Ports in: contents, discount, shipping_method. Port out: summary, after every input.
  class CartTotals
    include Foundation::Ports
    output :summary, ProgrammingParadigms::DataFlow, many: true

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
      gift_wrap = @gift_wrap ? @gift_wrap.call(@wrapped) : 0
      Rules::Pricing.summary(@lines, percentage: @discount&.dig(:percentage), shipping: @shipping, method: @method, extra: gift_wrap)
        .merge(promo_code: @discount&.dig(:code), gift_wrap_total: m[gift_wrap], shipping_method: @method,
               shipping_options: @shipping.options.map { |o| o.merge(cost: m[o[:cost]], free_above: o[:free_above] && m[o[:free_above]]) })
    end
  end
end
