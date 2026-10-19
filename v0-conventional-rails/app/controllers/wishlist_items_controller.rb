class WishlistItemsController < ApplicationController
  before_action :set_wishlist_item

  def destroy
    @wishlist_item.destroy!
    @cart_item = current_cart.items.find_by(product: @wishlist_item.product)
    flash.now[:notice] = "Removed from wishlist"
  end

  def add_to_cart
    @cart_item = current_cart.add_product(@wishlist_item.product)
    @wishlist_item.destroy!
    flash.now[:notice] = "Added to cart"
  end

  private
    def set_wishlist_item
      @wishlist_item = current_cart.wishlist_items.find(params[:id])
    end
end
