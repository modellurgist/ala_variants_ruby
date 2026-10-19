class Order < ApplicationRecord
  belongs_to :cart
  has_many :order_items, dependent: :destroy

  delegate :portal?, to: :cart

  validates :po_number, presence: true, if: :portal?
  validates :po_number, format: { with: /\APO-\d{4,}\z/, message: "must look like PO-1234" }, allow_blank: true, if: :portal?

  def reference
    format("GD-%06d", id)
  end
end
