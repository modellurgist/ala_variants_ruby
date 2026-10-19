class CartUndosController < ApplicationController
  def create
    @cart_item = current_cart.pending_removal
    @cart_item&.restore!
    flash.now[:notice] = "Item restored" if @cart_item
  end
end
