class Portal::OrdersController < ApplicationController
  def create
    @cart = current_portal_cart
    return redirect_to portal_path, alert: "Your order is empty" if @cart.items.none?

    @order = @cart.place_order(po_number: params.dig(:order, :po_number))
    if @order.persisted?
      session[:portal_order_id] = @order.id
      redirect_to submitted_portal_path, notice: "Order submitted"
    else
      render "portals/review", status: :unprocessable_entity
    end
  end
end
