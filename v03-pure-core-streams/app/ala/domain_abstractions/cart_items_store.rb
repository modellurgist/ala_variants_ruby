module DomainAbstractions
  # The lines table as a source and a sink (§5.2.2): answers a cart's stored lines, and applies the
  # changes a lines abstraction decided. Config: model, cart_id. Ports in: lookup (a request answered
  # with [{ id:, product_id:, quantity:, gift_wrapped: }]), apply ({ op:, ... } with op :quantity
  # { id:, quantity: }, :gift_wrap { id:, gift_wrapped: }, :remove { id: }), add ({ product_id:,
  # quantity: }). Port out: added (the stored line's snapshot, after add).
  class CartItemsStore
    include Foundation::Ports
    output :added, ProgrammingParadigms::DataFlow

    input(:lookup, ProgrammingParadigms::RequestResponse) { |_| mine.map { snapshot(_1) } }

    input(:apply, ProgrammingParadigms::DataFlow) do |change|
      case change[:op]
      when :quantity then mine.find(change[:id]).update!(quantity: change[:quantity])
      when :gift_wrap then mine.find(change[:id]).update!(gift_wrapped: change[:gift_wrapped])
      when :remove then mine.find(change[:id]).destroy!
      end
    end

    input(:add, ProgrammingParadigms::DataFlow) do |line|
      emit(:added, snapshot(@model.add(@cart_id, line[:product_id], line[:quantity])))
    end

    def initialize(model:, cart_id:) = (@model, @cart_id = model, cart_id)

    private

    def mine = @model.active.where(cart_id: @cart_id)
    def snapshot(item) = { id: item.id, product_id: item.product_id, quantity: item.quantity, gift_wrapped: item.gift_wrapped }
  end
end
