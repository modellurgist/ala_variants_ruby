class SavedItem < ApplicationRecord
  belongs_to :cart
  scope :for_cart, ->(cart_id) { where(cart_id:).order(:id) }
end
