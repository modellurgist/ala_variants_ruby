class PortalUndosController < ApplicationController
  include PortalScreen

  def create
    screen.input_port(:undo).send_event
    back_to_portal
  end

  def expire
    screen.input_port(:expire_undo).send_event
    back_to_portal
  end
end
