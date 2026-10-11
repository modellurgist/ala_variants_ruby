class PortalsController < ApplicationController
  include PortalScreen

  STEPS_BY_URL = { nil => :lines, "review" => :review, "submitted" => :submitted }.freeze

  def show
    screen.input_port(:show).push(STEPS_BY_URL[params[:step]])
    @s = screen
    @t = Screens::Portal::TEXTS
  end

  def review
    screen.input_port(:review).send_event
    redirect_to(screen.flash.any? ? portal_path : portal_step_path(:review), flash: screen.flash)
  end

  def edit_lines
    screen.input_port(:edit_lines).send_event
    redirect_to portal_path
  end

  def validate
    screen.input_port(:validate).push(po_params)
    @s = screen
    render turbo_stream: turbo_stream.replace(helpers.dom_id(screen.form, :form), partial: "portals/po_form", locals: { form: screen.form })
  end

  def submit
    screen.input_port(:submit).push(po_params)
    if screen.step == :submitted
      redirect_to portal_step_path(:submitted), flash: screen.flash
    else
      @s = screen
      @t = Screens::Portal::TEXTS
      render :show, status: :unprocessable_content
    end
  end

  private

  def po_params = params.expect(order_submission: [ :po_number, :notes ])
end
