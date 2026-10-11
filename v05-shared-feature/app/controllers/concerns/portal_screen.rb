# The portal's controllers share one screen per request and land on the portal after a change.
module PortalScreen
  extend ActiveSupport::Concern

  private

  def screen = @screen ||= Screens::Portal.new(cart_id: current_portal_cart_id)
  def back_to_portal = redirect_to(portal_path, flash: screen.flash)
end
