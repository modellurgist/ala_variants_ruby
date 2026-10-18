class CheckoutsController < ApplicationController
  STEPS_BY_URL = { nil => :address, "payment" => :payment }.freeze

  def create
    screen(cart_id).start
    redirect_to(screen.flash.any? ? cart_path : cart_checkout_path, flash: screen.flash)
  end

  def show
    screen.show(STEPS_BY_URL[params[:step]])
    return redirect_to cart_success_path if screen.step == :complete
    @s = screen
    @t = Screens::Checkout::TEXTS
  end

  def validate
    screen.validate(address_params)
    render turbo_stream: turbo_stream.replace(helpers.dom_id(screen.form, :form), partial: "checkouts/address_form", locals: { form: screen.form })
  end

  def address
    screen.submit_address(address_params)
    if screen.step == :payment
      redirect_to cart_checkout_step_path(:payment)
    else
      @s = screen
      @t = Screens::Checkout::TEXTS
      render :show, status: :unprocessable_content
    end
  end

  def edit_address
    screen.edit_address
    redirect_to cart_checkout_path
  end

  def pay
    screen.pay
    redirect_to cart_checkout_step_path(:payment), flash: screen.flash
  end

  private

  def screen(id = current_cart_id) = @screen ||= Screens::Checkout.new(cart_id: id)
  def address_params = params.expect(checkout: [ :name, :line1, :city, :postal_code ])
end
