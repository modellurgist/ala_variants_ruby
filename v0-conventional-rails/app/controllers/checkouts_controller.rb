class CheckoutsController < ApplicationController
  before_action :redirect_completed_cart, only: :payment
  before_action :require_items
  before_action :set_checkout

  def create
    redirect_to cart_checkout_path
  end

  def show
  end

  def update
    if @checkout.update(checkout_params)
      redirect_to payment_cart_checkout_path
    else
      render :show, status: :unprocessable_entity
    end
  end

  def validate
    @checkout.assign_attributes(checkout_params)
    @checkout.validate
  end

  def payment
    redirect_to cart_checkout_path unless address_complete?
  end

  def pay
    if !address_complete?
      redirect_to cart_checkout_path
    elsif current_cart.out_of_stock_items?
      redirect_to payment_cart_checkout_path, alert: "Some items are out of stock"
    else
      @checkout.start_payment! unless @checkout.processing?
      # Updating in place keeps the page's stream subscription, so the job's result can't be missed.
      respond_to do |format|
        format.turbo_stream { render turbo_stream: turbo_stream.replace("payment", partial: "checkouts/payment_status", locals: { checkout: @checkout }) }
        format.html { redirect_to payment_cart_checkout_path }
      end
    end
  end

  private
    # The payment job can finish before the shopper's browser loads this page.
    def redirect_completed_cart
      redirect_to success_cart_path if Cart.completed.exists?(id: session[:cart_id])
    end

    def require_items
      redirect_to cart_path, alert: "Your cart is empty" if current_cart.items.none?
    end

    def set_checkout
      @checkout = current_cart.checkout || current_cart.build_checkout
    end

    def address_complete?
      @checkout.persisted? && @checkout.valid?
    end

    def checkout_params
      params.expect(checkout: [ :name, :address, :city, :postal_code ])
    end
end
