module DomainAbstractions
  # Charges for a cart's line items through the payment gateway it is configured with. Config:
  # gateway (answers [:ok, reference] or [:error, reason] to charge(amount, currency, metadata)),
  # metadata (a lambda of the cart id). Called with { line_items:, cart_id: }; answers [:charged,
  # reference] or [:declined, reason].
  class Charge
    def charge(payment)
      items = payment[:line_items]
      amount = items.sum { _1[:unit_amount] * _1[:quantity] }
      status, value = @gateway.charge(amount, items.first[:currency], @metadata.(payment[:cart_id]))
      [ status == :ok ? :charged : :declined, value ]
    end

    def initialize(gateway:, metadata:) = (@gateway, @metadata = gateway, metadata)
  end
end
