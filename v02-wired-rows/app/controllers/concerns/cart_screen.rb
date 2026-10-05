# The cart page's controllers share one screen per request and land on the cart after a change.
module CartScreen
  extend ActiveSupport::Concern

  private

  def screen = @screen ||= Screens::Cart.new(cart_id:)
  def back_to_cart = redirect_to(cart_path, flash: screen.flash)
end
