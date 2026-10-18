# The cart page's controllers share one screen per request. A change answers with the patches the
# screen's outputs made (a Turbo request), or lands on the cart (a plain one).
module CartScreen
  extend ActiveSupport::Concern

  private

  def screen = @screen ||= Screens::Cart.new(cart_id:)

  def back_to_cart
    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: screen.patches.render(turbo_stream) +
                             [ turbo_stream.replace(Foundation::DomTargets.flash_id, partial: "elements/flash", locals: { flash: screen.flash }) ]
      end
      format.html { redirect_to(cart_path, flash: screen.flash) }
    end
  end
end
