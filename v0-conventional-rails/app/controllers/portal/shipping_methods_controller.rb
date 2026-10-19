class Portal::ShippingMethodsController < ShippingMethodsController
  private
    def cart
      current_portal_cart
    end
end
