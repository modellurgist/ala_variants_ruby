module DomainAbstractions
  # The wishlist table as a source and a sink. Config: model, cart_id. In: lookup (answers the product
  # ids), apply ({ op: :add | :remove, product_id: }).
  class WishlistStore
    def lookup = mine.pluck(:product_id)

    def apply(change)
      case change[:op]
      when :add then @model.create!(cart_id: @cart_id, product_id: change[:product_id])
      when :remove then mine.find_by(product_id: change[:product_id])&.destroy!
      end
      nil
    end

    def initialize(model:, cart_id:) = (@model, @cart_id = model, cart_id)

    private

    def mine = @model.for_cart(@cart_id)
  end
end
