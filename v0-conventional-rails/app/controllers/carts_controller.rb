class CartsController < ApplicationController
  def show
    @cart = current_cart
  end

  def success
    @order = Cart.completed.find_by(id: session[:cart_id])&.order
  end
end
