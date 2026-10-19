class PortalsController < ApplicationController
  before_action :set_cart, except: :submitted
  before_action :require_lines, only: :review

  def show
    @products = Product.order(:created_at, :id)
  end

  def review
    @order = Order.new(cart: @cart)
  end

  def validate
    @order = Order.new(cart: @cart, po_number: params.dig(:order, :po_number))
    @order.validate
  end

  def submitted
    @order = Order.find_by(id: session[:portal_order_id])
    redirect_to portal_path unless @order
  end

  private
    def set_cart
      @cart = current_portal_cart
    end

    def require_lines
      redirect_to portal_path, alert: "Your order is empty" if @cart.items.none?
    end
end
