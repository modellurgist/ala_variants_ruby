class Portal::LinesController < ApplicationController
  before_action :set_line, except: :create

  def create
    @line = current_portal_cart.add_product(Product.find(params[:product_id]), quantity: requested_quantity)
    flash.now[:notice] = "Added to order"
  end

  def update
    @line.update!(quantity: requested_quantity)
  end

  def destroy
    @line.remove!
  end

  private
    def set_line
      @line = current_portal_cart.items.find(params[:id])
    end

    def requested_quantity
      [ params[:quantity].to_i, 1 ].max
    end
end
