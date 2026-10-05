class CartItemsController < ApplicationController
  include CartScreen

  def update
    screen.input_port(:bump).push(item_id: params[:id].to_i, delta: params[:delta].to_i)
    back_to_cart
  end

  def destroy
    screen.input_port(:remove).push(params[:id].to_i)
    back_to_cart
  end

  def gift_wrap
    screen.input_port(:toggle_gift_wrap).push(params[:id].to_i)
    back_to_cart
  end

  def save
    screen.input_port(:save_for_later).push(params[:id].to_i)
    back_to_cart
  end

  def wishlist
    screen.input_port(:toggle_wishlist).push(params[:id].to_i)
    back_to_cart
  end
end
