class Product < ApplicationRecord
  has_many :cart_items, dependent: :destroy
  has_many :wishlist_items, dependent: :destroy

  validates :name, :amount, presence: true
  validates :amount, :stock, numericality: { only_integer: true, greater_than_or_equal_to: 0 }, allow_nil: true

  after_create_commit :broadcast_created
  after_update_commit :broadcast_updated
  after_destroy_commit :broadcast_destroyed

  def stock_status
    if stock <= 0
      :out_of_stock
    elsif stock <= Rails.configuration.x.store.low_stock_threshold
      :low_stock
    else
      :in_stock
    end
  end

  def in_stock?(quantity = 1)
    stock >= quantity
  end

  def decrement_stock!(quantity)
    with_lock { update!(stock: stock - quantity) }
  end

  private
    def broadcast_created
      broadcast_append_to "products"
      broadcast_append_to "portal_products", target: "portal_products", partial: "portals/product"
    end

    def broadcast_updated
      broadcast_replace_to "products"
      broadcast_replace_to "portal_products", target: [ self, :portal ], partial: "portals/product"
      cart_items.active.joins(:cart).merge(Cart.open).find_each(&:broadcast_row)
    end

    def broadcast_destroyed
      broadcast_remove_to "products"
      broadcast_remove_to "portal_products", target: [ self, :portal ]
    end
end
