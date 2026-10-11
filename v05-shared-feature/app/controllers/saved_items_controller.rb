class SavedItemsController < ApplicationController
  include CartScreen

  def move
    change { _1.input_port(:move_to_cart).push(params[:id].to_i) }
  end
end
