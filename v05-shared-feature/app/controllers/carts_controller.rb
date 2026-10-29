class CartsController < ApplicationController
  include CartScreen

  def show = show_cart

  # a product changed elsewhere: answered with the patches of what the cart's lists hold
  def live
    with_screen do |screen|
      screen.input_port(:live).push(live_message)
      render turbo_stream: screen.patches.render(turbo_stream)
    end
  end
end
