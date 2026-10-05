class PortalLinesController < ApplicationController
  include PortalScreen

  def create
    screen.input_port(:add).push(product_id: params[:product_id].to_i, quantity: params[:quantity].to_i)
    back_to_portal
  end

  def update
    screen.input_port(:set_quantity).push(item_id: params[:id].to_i, quantity: params[:quantity].to_i)
    back_to_portal
  end

  def destroy
    screen.input_port(:remove).push(params[:id].to_i)
    back_to_portal
  end
end
