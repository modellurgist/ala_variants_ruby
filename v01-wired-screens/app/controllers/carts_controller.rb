class CartsController < ApplicationController
  include CartScreen

  def show
    screen.input_port(:load).send_event
    @s = screen
    @texts = Screens::Cart::TEXTS
  end
end
