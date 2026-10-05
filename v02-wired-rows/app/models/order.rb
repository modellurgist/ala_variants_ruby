class Order < ApplicationRecord
  belongs_to :cart

  # Records the order for a cart and completes the cart.
  def self.place(cart_id, po_number: nil)
    transaction do
      Cart.find(cart_id).complete!
      create!(cart_id:, po_number:)
    end
  end
end
