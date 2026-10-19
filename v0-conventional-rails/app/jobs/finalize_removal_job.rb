class FinalizeRemovalJob < ApplicationJob
  discard_on ActiveJob::DeserializationError

  def perform(cart_item, removed_at)
    return unless cart_item.removed_at == removed_at

    cart_item.destroy!
    Turbo::StreamsChannel.broadcast_update_to cart_item.cart, target: "undo_banner", html: ""
  end
end
