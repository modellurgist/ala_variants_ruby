module CurrentCart
  extend ActiveSupport::Concern

  included do
    helper_method :current_cart, :current_portal_cart
  end

  private
    def current_cart
      @current_cart ||= find_or_create_cart(:cart_id, :storefront)
    end

    def current_portal_cart
      @current_portal_cart ||= find_or_create_cart(:portal_cart_id, :portal)
    end

    def find_or_create_cart(session_key, kind)
      Cart.open.find_by(id: session[session_key], kind:) || Cart.create!(kind:).tap { |cart| session[session_key] = cart.id }
    end
end
