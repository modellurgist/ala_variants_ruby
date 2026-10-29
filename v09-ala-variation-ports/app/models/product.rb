class Product < ApplicationRecord
  validates :name, :amount, presence: true
  validates :amount, :stock, numericality: { only_integer: true, greater_than_or_equal_to: 0 }, allow_nil: true

  def self.stock_levels(ids) = where(id: ids).pluck(:id, :stock).to_h

  # Takes `quantity` from stock if there is enough; answers the product with its new level, or nil.
  def self.decrement_stock(id, quantity)
    taken = where(id:).where("stock >= ?", quantity).update_all([ "stock = stock - ?", quantity ])
    taken.positive? ? find(id) : nil
  end
end
