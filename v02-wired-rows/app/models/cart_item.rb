# A stored line of a cart: the lines abstraction both the storefront and the portal build on. A line
# marked `removed_at` is a removal that can still be undone.
class CartItem < ApplicationRecord
  belongs_to :cart

  scope :active, -> { where(removed_at: nil).order(:id) }
  scope :pending_removal, -> { where.not(removed_at: nil) }

  # Adds `quantity` of a product, growing a line already there.
  def self.add(cart_id, product_id, quantity = 1)
    line = find_or_initialize_by(cart_id:, product_id:)
    line.quantity = line.new_record? ? quantity : line.quantity + quantity
    line.removed_at = nil
    line.save!
    line
  end
end
