class CartItemsController < ApplicationController
  include CartScreen

  def update
    change { _1.input_port(:bump).push(item_id: params[:id].to_i, delta: params[:delta].to_i) }
  end

  def destroy
    change { _1.input_port(:remove).push(params[:id].to_i) }
  end

  def gift_wrap
    change { _1.input_port(:toggle_gift_wrap).push(params[:id].to_i) }
  end

  def save
    change { _1.input_port(:save_for_later).push(params[:id].to_i) }
  end

  def wishlist
    change { _1.input_port(:toggle_wishlist).push(params[:id].to_i) }
  end
end
