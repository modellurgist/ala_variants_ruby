class PaymentJob < ApplicationJob
  def perform(checkout)
    checkout.complete_payment
  end
end
