class PortalUndosController < ApplicationController
  include PortalScreen

  def create
    screen.undo
    back_to_portal
  end

  def expire
    screen.expire_undo
    back_to_portal
  end
end
