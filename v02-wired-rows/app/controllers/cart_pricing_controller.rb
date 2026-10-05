class CartPricingController < ApplicationController
  include CartScreen

  def promo
    screen.input_port(:enter_promo).push(params[:code].to_s)
    back_to_cart
  end

  def shipping
    screen.input_port(:select_shipping).push(params[:shipping_method].to_s)
    back_to_cart
  end
end
