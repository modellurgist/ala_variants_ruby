# Where a portal draft's submission is: its step and the purchase order entered so far. The purchase
# order is validated when it is submitted (the :submit context).
class OrderSubmission < ApplicationRecord
  belongs_to :cart

  validates :po_number, presence: true, on: :submit
  validates :po_number, format: { with: /\APO-\d{4,}\z/ }, on: :submit, allow_blank: true

  def self.for_cart(cart_id) = find_or_create_by!(cart_id:)
end
