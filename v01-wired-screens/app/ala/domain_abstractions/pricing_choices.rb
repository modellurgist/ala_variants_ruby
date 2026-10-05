module DomainAbstractions
  # The promo code and shipping method a shopper chose for a cart, kept in a store of their own.
  # Config: store, cart_id, promo (a ValidatePromo, or nil for a store with no codes), shipping (a
  # CalculateShipping), default_method. Ports out: discount ({ code:, percentage: } or nil),
  # shipping_method (after load or a choice), promo_applied and promo_rejected (the code entered).
  class PricingChoices
    include Foundation::Ports
    output :discount, ProgrammingParadigms::DataFlow
    output :shipping_method, ProgrammingParadigms::DataFlow
    output :promo_applied, ProgrammingParadigms::DataFlow, many: true
    output :promo_rejected, ProgrammingParadigms::DataFlow, many: true

    input(:load, ProgrammingParadigms::Event) do
      choice = mine
      code, percentage = @promo&.call(choice.promo_code)
      emit(:discount, code && { code:, percentage: })
      emit(:shipping_method, method_of(choice))
    end

    input(:enter_promo, ProgrammingParadigms::DataFlow) do |entered|
      code, _ = @promo&.call(entered)
      if code
        mine.update!(promo_code: code)
        emit(:promo_applied, code)
      else
        emit(:promo_rejected, entered)
      end
    end

    input(:select_shipping, ProgrammingParadigms::DataFlow) do |method|
      mine.update!(shipping_method: method.to_s) if @shipping.method?(method.to_sym)
    end

    def initialize(store:, cart_id:, promo:, shipping:, default_method:)
      @store, @cart_id, @promo, @shipping, @default = store, cart_id, promo, shipping, default_method
    end

    private

    def mine = @store.for_cart(@cart_id)
    def method_of(choice) = choice.shipping_method&.to_sym || @default
  end
end
