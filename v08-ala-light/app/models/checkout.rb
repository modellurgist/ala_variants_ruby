# Where a cart's checkout is: its step and the address entered so far. The address is validated when
# it is submitted (the :address context), not when the checkout record is first created.
class Checkout < ApplicationRecord
  belongs_to :cart

  validates :name, :line1, :city, :postal_code, presence: true, on: :address
  validates :postal_code, format: { with: /\A\d{4,10}\z/ }, on: :address, allow_blank: true

  def self.for_cart(cart_id) = find_or_create_by!(cart_id:)
end
