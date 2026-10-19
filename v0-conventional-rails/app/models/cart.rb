class Cart < ApplicationRecord
  enum :status, { open: "open", completed: "completed", abandoned: "abandoned" }, default: "open"
  enum :kind, { storefront: "storefront", portal: "portal" }, default: "storefront"

  has_many :cart_items, dependent: :destroy
  has_many :items, -> { active.where(saved_for_later: false).order(:created_at, :id) }, class_name: "CartItem"
  has_many :saved_items, -> { active.where(saved_for_later: true).order(:updated_at, :id) }, class_name: "CartItem"
  has_many :wishlist_items, -> { order(:created_at, :id) }, dependent: :destroy
  has_one :checkout, dependent: :destroy
  has_one :order

  validates :shipping_method, inclusion: { in: ->(_) { ShippingMethod.keys } }

  def self.undo_window
    Rails.configuration.x.store.undo_window_seconds.seconds
  end

  def add_product(product, quantity: 1)
    item = cart_items.find_or_initialize_by(product:)
    if item.new_record? || item.removed_at?
      item.assign_attributes(quantity:, removed_at: nil, saved_for_later: false, gift_wrap: false)
    else
      item.assign_attributes(quantity: item.quantity + quantity, saved_for_later: false)
    end
    item.save!
    item
  end

  def pending_removal
    cart_items.where.not(removed_at: nil).order(:removed_at).last
  end

  def apply_promo_code(code)
    code = code.to_s.strip.upcase
    return false unless PromoCode.percent_for(code)

    update!(promo_code: code)
  end

  def wishlisted?(product)
    wishlist_items.exists?(product:)
  end

  def toggle_wishlist(product)
    item = wishlist_items.find_by(product:)
    item ? item.destroy! : wishlist_items.create!(product:)
  end

  def totals
    CartTotals.new(self)
  end

  def out_of_stock_items?
    items.includes(:product).any? { |item| !item.product.in_stock?(item.quantity) }
  end

  def place_order(po_number: nil, decrement_stock: false)
    order = build_order(po_number:, total_cents: totals.total)
    return order unless order.valid?

    transaction do
      order.save!
      items.includes(:product).each do |item|
        order.order_items.create!(product: item.product, name: item.product.name, quantity: item.quantity, unit_amount: item.product.amount)
        item.product.decrement_stock!(item.quantity) if decrement_stock
      end
      completed!
    end
    order
  end
end
