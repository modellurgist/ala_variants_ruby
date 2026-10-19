class Checkout < ApplicationRecord
  belongs_to :cart

  enum :payment_status, { processing: "processing", failed: "failed" }

  validates :name, :address, :city, :postal_code, presence: true

  def self.gateway
    Rails.configuration.x.store.payment_gateway.constantize.new
  end

  def start_payment!
    processing!
    PaymentJob.perform_later(self)
  end

  def complete_payment(gateway: self.class.gateway)
    redirect_url = gateway.checkout(line_items:, success_url: Rails.application.routes.url_helpers.success_cart_path)
    if redirect_url
      cart.place_order(decrement_stock: true)
      Turbo::StreamsChannel.broadcast_action_to self, action: :redirect, attributes: { url: redirect_url }
    else
      failed!
      broadcast_replace_to self, target: "payment", partial: "checkouts/payment_status", locals: { checkout: self }
    end
  end

  def line_items
    cart.items.includes(:product).map do |item|
      { name: item.product.name, unit_amount: item.product.amount, quantity: item.quantity }
    end
  end
end
