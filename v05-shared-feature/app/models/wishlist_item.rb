class WishlistItem < ApplicationRecord
  belongs_to :cart
  # ala:accept r1 -- the write stamp is the store's own: a row's commit moves its cart's version and decides nothing above
  after_commit { Cart.bump(cart_id) }
  scope :for_cart, ->(cart_id) { where(cart_id:).order(:id) }
end
