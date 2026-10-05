class ApplicationController < ActionController::Base
  allow_browser versions: :modern
  helper_method :cart_id, :portal_cart_id

  private

  # The session's open storefront cart (R1.1): the one it has while it stays open, a fresh one once
  # it has been checked out. The portal's draft is a separate cart under its own key (R1.2).
  def cart_id = session[:cart_id] = Cart.ensure_open(session[:cart_id])
  def portal_cart_id = session[:portal_cart_id] = Cart.ensure_open(session[:portal_cart_id])

  # The cart the session was last using, open or just completed: for a flow that outlives its cart.
  def current_cart_id = session[:cart_id] || cart_id
  def current_portal_cart_id = session[:portal_cart_id] || portal_cart_id
end
