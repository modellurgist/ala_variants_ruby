module DomainAbstractions
  # The lines table as a source and a sink (§5.2.2): answers a cart's stored lines, and applies the
  # changes a lines abstraction decided. Config: model, cart_id. In: lookup (answers [{ id:,
  # product_id:, quantity:, gift_wrapped: }]), apply ({ op:, ... } with op :quantity { id:, quantity: },
  # :gift_wrap { id:, gift_wrapped: }, :remove { id: }), add ({ product_id:, quantity: }). Out: added
  # (the stored line's `to_line`, after add).
  class CartItemsStore
    OUTPUTS = %i[added].freeze

    def lookup = mine.map(&:to_line)

    def apply(change)
      case change[:op]
      when :quantity then mine.find(change[:id]).update!(quantity: change[:quantity])
      when :gift_wrap then mine.find(change[:id]).update!(gift_wrapped: change[:gift_wrapped])
      when :remove then mine.find(change[:id]).destroy!
      end
      nil
    end

    def add(line) = { added: @model.add(@cart_id, line[:product_id], line[:quantity]).to_line }

    def initialize(model:, cart_id:) = (@model, @cart_id = model, cart_id)

    private

    def mine = @model.active.where(cart_id: @cart_id)
  end
end
