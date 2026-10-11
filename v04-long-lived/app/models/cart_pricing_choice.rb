# The storefront cart's chosen promo code and shipping method.
class CartPricingChoice < ApplicationRecord
  belongs_to :cart
  # ala:accept r1 -- the write stamp is the store's own: a row's commit moves its cart's version and decides nothing above
  after_commit { Cart.bump(cart_id) }
  def self.for_cart(cart_id) = find_or_create_by!(cart_id:)
end
