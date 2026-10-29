class WishlistItemsController < ApplicationController
  include CartScreen

  def destroy
    screen.remove_wishlisted(params[:id].to_i)
    back_to_cart
  end

  def add_to_cart
    screen.add_wishlisted(params[:id].to_i)
    back_to_cart
  end
end
