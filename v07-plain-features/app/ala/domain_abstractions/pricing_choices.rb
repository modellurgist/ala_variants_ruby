module DomainAbstractions
  # The promo code and shipping method a shopper chose for a cart, kept in a store of their own.
  # Config: store, cart_id, promo (a ValidatePromo, or nil for a store with no codes), shipping (a
  # CalculateShipping), default_method. In: load, enter_promo (a code), select_shipping (a method).
  # Out: discount ({ code:, percentage: } or nil), shipping_method (after load or a choice),
  # promo_applied and promo_rejected (the code entered).
  class PricingChoices
    OUTPUTS = %i[discount shipping_method promo_applied promo_rejected].freeze

    def load
      choice = mine
      code, percentage = @promo&.call(choice.promo_code)
      { discount: code && { code:, percentage: }, shipping_method: method_of(choice) }
    end

    def enter_promo(entered)
      code, percentage = @promo&.call(entered)
      return { promo_rejected: entered } unless code
      mine.update!(promo_code: code)
      { discount: { code:, percentage: }, promo_applied: code }
    end

    # A choice is announced as it is made, so the page can follow it without a reload.
    def select_shipping(method)
      return unless @shipping.method?(method.to_sym)
      mine.update!(shipping_method: method.to_s)
      { shipping_method: method.to_sym }
    end

    def initialize(store:, cart_id:, promo:, shipping:, default_method:)
      @store, @cart_id, @promo, @shipping, @default = store, cart_id, promo, shipping, default_method
    end

    private

    def mine = @store.for_cart(@cart_id)
    def method_of(choice) = choice.shipping_method&.to_sym || @default
  end
end
