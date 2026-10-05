module DomainAbstractions
  # Charges for a cart's line items through the payment gateway it is configured with. Config:
  # gateway (answers [:ok, reference] or [:error, reason] to charge(amount, currency, metadata)),
  # metadata (a lambda of the cart id). In: charge, { line_items:, cart_id: }. Out: charged (the
  # reference), declined (the reason).
  class Charge
    include Foundation::Ports
    output :charged, ProgrammingParadigms::DataFlow, many: true
    output :declined, ProgrammingParadigms::DataFlow, many: true

    input(:charge, ProgrammingParadigms::DataFlow) do |payment|
      items = payment[:line_items]
      amount = items.sum { _1[:unit_amount] * _1[:quantity] }
      status, value = @gateway.charge(amount, items.first[:currency], @metadata.(payment[:cart_id]))
      status == :ok ? emit(:charged, value) : emit(:declined, value)
    end

    def initialize(gateway:, metadata:) = (@gateway, @metadata = gateway, metadata)
  end
end
