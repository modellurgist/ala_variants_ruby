class WishlistItem < ApplicationRecord
  belongs_to :cart
  belongs_to :product
  scope :for_cart, ->(cart_id) { where(cart_id:).includes(:product).order(:id) }
end
