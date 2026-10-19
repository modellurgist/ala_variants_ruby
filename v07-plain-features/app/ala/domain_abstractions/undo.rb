module DomainAbstractions
  # Holds one removal open for a while so it can be undone (R4). A held line stays in the store, marked,
  # and is deleted once the window elapses or another removal replaces it. Holding it clears its gift
  # wrap (R3.4), so a restored line comes back unwrapped. Config: lines (the store, whose
  # `pending_removal` scope, `removed_at` and `gift_wrapped` columns and `to_line` it uses), cart_id,
  # window (a duration). In: load, capture (an item id), restore, expire. Out: pending (whether a
  # removal can be undone, after load and after every change), restored (the line's `to_line`).
  class Undo
    OUTPUTS = %i[pending restored].freeze

    def load
      finalize(held.where(removed_at: ..(Time.current - @window)))
      { pending: held.exists? }
    end

    # Only the latest removal is undoable: holding a new one makes any other final.
    def capture(item_id)
      finalize(held.where.not(id: item_id))
      @lines.find(item_id).update!(removed_at: Time.current, gift_wrapped: false)
      { pending: true }
    end

    def restore
      item = held.where(removed_at: (Time.current - @window)..).first
      item&.update!(removed_at: nil)
      finalize(held) unless item
      { restored: item&.to_line, pending: false }.compact
    end

    def expire
      finalize(held)
      { pending: false }
    end

    def initialize(lines:, cart_id:, window:) = (@lines, @cart_id, @window = lines, cart_id, window)

    private

    def held = @lines.pending_removal.where(cart_id: @cart_id)

    def finalize(scope) = scope.each(&:destroy!)
  end
end
