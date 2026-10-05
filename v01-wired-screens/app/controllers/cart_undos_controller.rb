class CartUndosController < ApplicationController
  include CartScreen

  def create
    screen.input_port(:undo).send_event
    back_to_cart
  end

  def expire
    screen.input_port(:expire_undo).send_event
    back_to_cart
  end
end
