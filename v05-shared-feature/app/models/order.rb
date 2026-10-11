class Order < ApplicationRecord
  belongs_to :cart
  # ala:accept r1 -- the write stamp is the store's own: a row's commit moves its cart's version and decides nothing above
  after_commit { Cart.bump(cart_id) }

  # Records the order for a cart and completes the cart.
  def self.place(cart_id, po_number: nil)
    transaction do
      Cart.find(cart_id).complete!
      create!(cart_id:, po_number:)
    end
  end
end
