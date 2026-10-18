class PortalLinesController < ApplicationController
  include PortalScreen

  def create
    screen.add(product_id: params[:product_id].to_i, quantity: params[:quantity].to_i)
    back_to_portal
  end

  def update
    screen.set_quantity(item_id: params[:id].to_i, quantity: params[:quantity].to_i)
    back_to_portal
  end

  def destroy
    screen.remove(params[:id].to_i)
    back_to_portal
  end
end
