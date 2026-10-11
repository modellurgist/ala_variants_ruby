class WishlistItemsController < ApplicationController
  include CartScreen

  def destroy
    change { _1.input_port(:remove_wishlisted).push(params[:id].to_i) }
  end

  def add_to_cart
    change { _1.input_port(:add_wishlisted).push(params[:id].to_i) }
  end
end
