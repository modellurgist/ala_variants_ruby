class SavedItemsController < ApplicationController
  include CartScreen

  def move
    screen.input_port(:move_to_cart).push(params[:id].to_i)
    back_to_cart
  end
end
