class CartUndosController < ApplicationController
  include CartScreen

  def create
    change { _1.input_port(:undo).send_event }
  end

  def expire
    change { _1.input_port(:expire_undo).send_event }
  end
end
