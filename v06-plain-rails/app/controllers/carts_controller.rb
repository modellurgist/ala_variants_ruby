class CartsController < ApplicationController
  include CartScreen

  def show
    screen.load
    @s = screen
    @texts = Screens::Cart::TEXTS
  end
end
