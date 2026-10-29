class CartUndosController < ApplicationController
  include CartScreen

  def create
    screen.undo
    back_to_cart
  end

  def expire
    screen.expire_undo
    back_to_cart
  end
end
