class ShippingMethodsController < ApplicationController
  def update
    cart.update(shipping_method: params[:shipping_method])
  end

  private
    def cart
      current_cart
    end
end
