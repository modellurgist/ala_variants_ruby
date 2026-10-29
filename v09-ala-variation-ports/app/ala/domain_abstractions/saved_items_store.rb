module DomainAbstractions
  # The saved-items table as a source and a sink. Config: model, cart_id. `lookup` answers [{ id:,
  # product_id:, quantity: }]; saving a product already saved keeps the first.
  class SavedItemsStore
    def lookup = mine.map { { id: _1.id, product_id: _1.product_id, quantity: _1.quantity } }
    def stash(line) = (@model.find_or_create_by!(cart_id: @cart_id, product_id: line[:product_id]) { _1.quantity = line[:quantity] }; nil)
    def remove(id) = (mine.find(id).destroy!; nil)

    def initialize(model:, cart_id:) = (@model, @cart_id = model, cart_id)

    private

    def mine = @model.for_cart(@cart_id)
  end
end
