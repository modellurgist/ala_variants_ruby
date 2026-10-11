module DomainAbstractions
  # The saved-items table as a source and a sink. Config: model, cart_id. Ports in: lookup (a
  # request answered with [{ id:, product_id:, quantity: }]), apply ({ op: :stash, product_id:,
  # quantity: } or { op: :remove, id: }).
  class SavedItemsStore
    include Foundation::Ports

    input(:lookup, ProgrammingParadigms::RequestResponse) { |_| mine.map { { id: _1.id, product_id: _1.product_id, quantity: _1.quantity } } }

    input(:apply, ProgrammingParadigms::DataFlow) do |change|
      case change[:op]
      when :stash then @model.find_or_create_by!(cart_id: @cart_id, product_id: change[:product_id]) { _1.quantity = change[:quantity] }
      when :remove then mine.find(change[:id]).destroy!
      end
    end

    def initialize(model:, cart_id:) = (@model, @cart_id = model, cart_id)

    private

    def mine = @model.for_cart(@cart_id)
  end
end
