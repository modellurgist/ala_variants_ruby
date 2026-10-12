module DomainAbstractions
  # The saved-items table as a source and a sink. Config: model, cart_id. In: lookup (answers [{ id:,
  # product_id:, quantity: }]), apply ({ op: :stash, product_id:, quantity: } or { op: :remove, id: }).
  class SavedItemsStore
    def lookup = mine.map { { id: _1.id, product_id: _1.product_id, quantity: _1.quantity } }

    def apply(change)
      case change[:op]
      when :stash then @model.find_or_create_by!(cart_id: @cart_id, product_id: change[:product_id]) { _1.quantity = change[:quantity] }
      when :remove then mine.find(change[:id]).destroy!
      end
      nil
    end

    def initialize(model:, cart_id:) = (@model, @cart_id = model, cart_id)

    private

    def mine = @model.for_cart(@cart_id)
  end
end
