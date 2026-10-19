class CartTotals
  attr_reader :cart

  def initialize(cart)
    @cart = cart
    @items = cart.items.includes(:product).to_a
  end

  def empty?
    @items.empty?
  end

  def item_count
    @items.sum(&:quantity)
  end

  def subtotal
    @items.sum(&:line_total)
  end

  def promo_percent
    cart.storefront? && cart.promo_code ? PromoCode.percent_for(cart.promo_code) : nil
  end

  def discount
    promo_percent ? subtotal * promo_percent / 100 : 0
  end

  def gift_wrap
    cart.storefront? ? @items.count(&:gift_wrap?) * Rails.configuration.x.store.gift_wrap_cents : 0
  end

  def volume_tier
    return unless cart.portal?

    Rails.configuration.x.store.volume_tiers.find { |tier| subtotal >= tier[:min_cents] }
  end

  def volume_discount
    volume_tier ? subtotal * volume_tier[:percent] / 100 : 0
  end

  def shipping_method
    ShippingMethod.find(cart.shipping_method)
  end

  def shipping
    shipping_method.cost_for(subtotal)
  end

  def shipping_label
    shipping.zero? ? "Free" : shipping_method.label
  end

  def total
    subtotal - discount - volume_discount + gift_wrap + shipping
  end
end
