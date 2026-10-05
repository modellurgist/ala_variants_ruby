# The storefront cart's chosen promo code and shipping method.
class CartPricingChoice < ApplicationRecord
  belongs_to :cart
  def self.for_cart(cart_id) = find_or_create_by!(cart_id:)
end
