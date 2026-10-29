module DomainAbstractions
  # The wishlist table as a source and a sink. Config: model, cart_id. `lookup` answers the product ids.
  class WishlistStore
    def lookup = mine.pluck(:product_id)
    def add(product_id) = (@model.create!(cart_id: @cart_id, product_id:); nil)
    def remove(product_id) = (mine.find_by(product_id:)&.destroy!; nil)

    def initialize(model:, cart_id:) = (@model, @cart_id = model, cart_id)

    private

    def mine = @model.for_cart(@cart_id)
  end
end
