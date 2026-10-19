class Product < ApplicationRecord
  # ala:accept r1 -- the write stamp is the store's own: a product's commit moves the version of every open cart holding it and decides nothing above
  after_commit { Cart.bump(Cart.holding(id)) }
  validates :name, :amount, presence: true
  validates :amount, :stock, numericality: { only_integer: true, greater_than_or_equal_to: 0 }, allow_nil: true

  def self.stock_levels(ids) = where(id: ids).pluck(:id, :stock).to_h

  # Takes `quantity` from stock if there is enough; answers the product with its new level, or nil.
  # Through the record, under its row lock, so the commit moves the stamps of the carts that show it.
  def self.decrement_stock(id, quantity)
    transaction do
      product = lock.find(id)
      next unless product.stock >= quantity
      product.tap { _1.update!(stock: _1.stock - quantity) }
    end
  end
end
