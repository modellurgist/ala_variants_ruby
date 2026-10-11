# The cart page's controllers share the cart's long-lived screen, one request at a time. A change
# answers with the patches the screen's outputs made (a Turbo request), or lands on the cart (a
# plain one). Both run inside the screen's turn, so what is rendered is what this request made.
module CartScreen
  extend ActiveSupport::Concern

  private

  def with_screen(&) = ProgrammingParadigms::LongLived.named(:cart_screens).with(cart_id, &)

  def show_cart
    with_screen do |screen|
      screen.input_port(:show).send_event
      @s = screen
      @texts = Screens::Cart::TEXTS
      render :show
    end
  end

  def change
    with_screen do |screen|
      yield screen
      respond_to do |format|
        format.turbo_stream do
          render turbo_stream: screen.patches.render(turbo_stream) +
                               [ turbo_stream.replace(Foundation::DomTargets.flash_id, partial: "elements/flash", locals: { flash: screen.flash }) ]
        end
        format.html { redirect_to(cart_path, flash: screen.flash) }
      end
    end
  end
end
