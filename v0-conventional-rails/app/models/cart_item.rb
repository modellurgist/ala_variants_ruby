class CartItem < ApplicationRecord
  belongs_to :cart
  belongs_to :product

  scope :active, -> { where(removed_at: nil) }

  validates :quantity, numericality: { only_integer: true, greater_than_or_equal_to: 1 }

  def line_total
    product.amount * quantity
  end

  def wishlisted?
    cart.wishlisted?(product)
  end

  # Only the latest removal stays undoable, so any earlier pending one becomes final here.
  def remove!
    transaction do
      cart.cart_items.where.not(removed_at: nil).where.not(id:).destroy_all
      update!(removed_at: Time.current, gift_wrap: false)
    end
    FinalizeRemovalJob.set(wait: Cart.undo_window).perform_later(self, removed_at)
  end

  def restore!
    update!(removed_at: nil)
  end

  def save_for_later!
    update!(saved_for_later: true)
  end

  def move_to_cart!
    update!(saved_for_later: false)
  end

  def broadcast_row
    if cart.portal?
      broadcast_replace_to cart, partial: "portal/lines/line", locals: { line: self }
    else
      broadcast_replace_to cart, partial: "cart_items/cart_item", locals: { cart_item: self }
    end
  end
end
