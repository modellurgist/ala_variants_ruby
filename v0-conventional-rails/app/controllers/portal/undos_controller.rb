class Portal::UndosController < ApplicationController
  def create
    @line = current_portal_cart.pending_removal
    @line&.restore!
    flash.now[:notice] = "Item restored" if @line
  end
end
