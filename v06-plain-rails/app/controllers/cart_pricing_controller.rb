class CartPricingController < ApplicationController
  include CartScreen

  def promo
    screen.enter_promo(params[:code].to_s)
    back_to_cart
  end

  def shipping
    screen.select_shipping(params[:shipping_method].to_s)
    back_to_cart
  end
end
