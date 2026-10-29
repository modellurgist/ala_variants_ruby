class SavedItemsController < ApplicationController
  include CartScreen

  def move
    screen.move_to_cart(params[:id].to_i)
    back_to_cart
  end
end
