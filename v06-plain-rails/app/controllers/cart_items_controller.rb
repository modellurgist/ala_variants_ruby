class CartItemsController < ApplicationController
  include CartScreen

  def update
    screen.bump(item_id: params[:id].to_i, delta: params[:delta].to_i)
    back_to_cart
  end

  def destroy
    screen.remove(params[:id].to_i)
    back_to_cart
  end

  def gift_wrap
    screen.toggle_gift_wrap(params[:id].to_i)
    back_to_cart
  end

  def save
    screen.save_for_later(params[:id].to_i)
    back_to_cart
  end

  def wishlist
    screen.toggle_wishlist(params[:id].to_i)
    back_to_cart
  end
end
