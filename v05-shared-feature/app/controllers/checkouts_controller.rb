class CheckoutsController < ApplicationController
  STEPS_BY_URL = { nil => :address, "payment" => :payment }.freeze

  def create
    with_screen(cart_id) do |s|
      s.input_port(:start).send_event
      redirect_to(s.flash.any? ? cart_path : cart_checkout_path, flash: s.flash)
    end
  end

  def show
    with_screen do |s|
      s.input_port(:show).push(STEPS_BY_URL[params[:step]])
      show_step(s)
    end
  end

  def validate
    with_screen do |s|
      s.input_port(:validate).push(address_params)
      render turbo_stream: turbo_stream.replace(helpers.dom_id(s.form, :form), partial: "checkouts/address_form", locals: { form: s.form })
    end
  end

  def address
    with_screen do |s|
      s.input_port(:submit_address).push(address_params)
      show_address_result(s)
    end
  end

  def edit_address
    with_screen { _1.input_port(:edit_address).send_event }
    redirect_to cart_checkout_path
  end

  def pay
    with_screen do |s|
      s.input_port(:pay).send_event
      redirect_to cart_checkout_step_path(:payment), flash: s.flash
    end
  end

  # A waiting page asks in case it missed the broadcast; answering "processing" could overwrite an outcome that arrived meanwhile.
  def status
    with_screen do |s|
      s.input_port(:show).push(nil)
      show_outcome(s)
    end
  end

  def live
    with_screen do |s|
      s.input_port(:live).push(live_message)
      show_outcome(s)
    end
  end

  private

  # the cart's kept checkout, one request at a time; for a flow that outlives its cart, the cart last used
  def with_screen(id = current_cart_id, &) = ProgrammingParadigms::LongLived.named(:checkout_screens).with(id, &)
  def address_params = params.expect(checkout: [ :name, :line1, :city, :postal_code ])

  # rendered inside the screen's turn, so the page is what this request made
  def show_step(s)
    return redirect_to cart_success_path if s.step == :complete
    @s = s
    @t = Screens::Checkout::TEXTS
    render :show
  end

  def show_outcome(s)
    return head(:no_content) unless Screens::Checkout::OUTCOMES.include?(s.step)
    @t = Screens::Checkout::TEXTS
    render turbo_stream: turbo_stream.replace(Screens::Checkout::STATUS_TARGET, partial: Screens::Checkout::STEP_PARTIALS.fetch(s.step))
  end

  def show_address_result(s)
    return redirect_to cart_checkout_step_path(:payment) if s.step == :payment
    @s = s
    @t = Screens::Checkout::TEXTS
    render :show, status: :unprocessable_content
  end
end
