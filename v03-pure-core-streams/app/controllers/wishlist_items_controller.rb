class WishlistItemsController < ApplicationController
  include CartScreen

  def destroy
    screen.input_port(:remove_wishlisted).push(params[:id].to_i)
    back_to_cart
  end

  def add_to_cart
    screen.input_port(:add_wishlisted).push(params[:id].to_i)
    back_to_cart
  end
end
