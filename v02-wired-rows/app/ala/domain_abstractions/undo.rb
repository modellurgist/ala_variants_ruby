module DomainAbstractions
  # Holds one removal open for a while so it can be undone (R4). A held line stays in the store, marked,
  # and is deleted once the window elapses or another removal replaces it. Config: lines (the store,
  # whose `pending_removal` scope and `removed_at` column it uses), cart_id, window (a duration).
  # Ports in: load, capture (an item id), restore, expire. Ports out: pending (whether a removal can
  # be undone, after load), restored (the line's id).
  class Undo
    include Foundation::Ports
    output :pending, ProgrammingParadigms::DataFlow
    output :restored, ProgrammingParadigms::DataFlow, many: true

    input(:load, ProgrammingParadigms::Event) do
      finalize(held.where(removed_at: ..(Time.current - @window)))
      emit(:pending, held.exists?)
    end

    # Only the latest removal is undoable: holding a new one makes any other final.
    input(:capture, ProgrammingParadigms::DataFlow) do |item_id|
      finalize(held.where.not(id: item_id))
      @lines.find(item_id).update!(removed_at: Time.current)
    end

    input(:restore, ProgrammingParadigms::Event) do
      item = held.where(removed_at: (Time.current - @window)..).first
      item&.update!(removed_at: nil)
      item ? emit(:restored, item.id) : finalize(held)
    end

    input(:expire, ProgrammingParadigms::Event) { finalize(held) }

    def initialize(lines:, cart_id:, window:) = (@lines, @cart_id, @window = lines, cart_id, window)

    private

    def held = @lines.pending_removal.where(cart_id: @cart_id)

    def finalize(scope) = scope.each(&:destroy!)
  end
end
