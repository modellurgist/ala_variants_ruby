module Features
  # The lines of an order being edited, with a removal that can be undone for a while: Spray's
  # feature (§2.2), a composition of domain abstractions a page places as one part. Inside, a
  # `CartLines` value and an `Undo` are wired to each other; outside, the page wires this feature's
  # ports to a lines store, a product index, its totals and its patches. Used by the cart page (kept
  # across requests) and the portal page (built per request) with different rows and windows.
  # Config: cart_id, row (a LineRow: what a displayed line carries, URLs included), undo_lines (the store
  # `Undo` marks), undo_window (a duration).
  # Ports in: load, show, lines (a request), bump, set_quantity, remove, save_for_later,
  # toggle_gift_wrap, line (an item id), receive (a product id or { product_id:, quantity: }), arrived
  # (a stored line's snapshot, added or restored), undo, expire_undo.
  # Ports out: items and products (requests), changed and adding (for the lines store), fetch (an id
  # the store should hand back as a snapshot, after a restore), rows, row_added, row_changed,
  # row_removed, contents, saved, line, undo_pending, restored.
  class OrderLines
    include Foundation::Ports
    output :items, ProgrammingParadigms::RequestResponse
    output :products, ProgrammingParadigms::RequestResponse
    output :changed, ProgrammingParadigms::DataFlow
    output :adding, ProgrammingParadigms::DataFlow
    output :fetch, ProgrammingParadigms::DataFlow
    output :rows, ProgrammingParadigms::DataFlow
    output :row_added, ProgrammingParadigms::DataFlow
    output :row_changed, ProgrammingParadigms::DataFlow
    output :row_removed, ProgrammingParadigms::DataFlow
    output :contents, ProgrammingParadigms::DataFlow
    output :saved, ProgrammingParadigms::DataFlow, many: true
    output :line, ProgrammingParadigms::DataFlow
    output :undo_pending, ProgrammingParadigms::DataFlow, many: true
    output :restored, ProgrammingParadigms::DataFlow, many: true

    input(:load, ProgrammingParadigms::Event) { @undo.input_port(:load).send_event; @lines.input_port(:load).send_event }
    input(:show, ProgrammingParadigms::Event) { @undo.input_port(:load).send_event; @lines.input_port(:show).send_event }
    input(:lines, ProgrammingParadigms::RequestResponse) { |query| @lines.input_port(:lines).request(query) }
    input(:bump, ProgrammingParadigms::DataFlow) { |change| @lines.input_port(:bump).push(change) }
    input(:set_quantity, ProgrammingParadigms::DataFlow) { |change| @lines.input_port(:set_quantity).push(change) }
    input(:remove, ProgrammingParadigms::DataFlow) { |item_id| @lines.input_port(:remove).push(item_id) }
    input(:save_for_later, ProgrammingParadigms::DataFlow) { |item_id| @lines.input_port(:save_for_later).push(item_id) }
    input(:toggle_gift_wrap, ProgrammingParadigms::DataFlow) { |item_id| @lines.input_port(:toggle_gift_wrap).push(item_id) }
    input(:line, ProgrammingParadigms::DataFlow) { |item_id| @lines.input_port(:line).push(item_id) }
    input(:receive, ProgrammingParadigms::DataFlow) { |request| @lines.input_port(:receive).push(request) }
    input(:arrived, ProgrammingParadigms::DataFlow) { |item| @lines.input_port(:arrived).push(item) }
    input(:undo, ProgrammingParadigms::Event) { @undo.input_port(:restore).send_event }
    input(:expire_undo, ProgrammingParadigms::Event) { @undo.input_port(:expire).send_event }

    def parts = { lines: @lines, undo: @undo }

    def initialize(cart_id:, row:, undo_lines:, undo_window:)
      @lines = DomainAbstractions::CartLines.new(cart_id:, row:)
      @undo = DomainAbstractions::Undo.new(lines: undo_lines, cart_id:, window: undo_window)

      @lines.wire_to(@undo, from: :removed, to: :capture)
      forward(@lines, :items, :products, :changed, :adding, :rows, :row_added, :row_changed, :row_removed, :contents, :saved, :line)
      forward(@undo, pending: :undo_pending)
      # a restored line is back in the store; the page's store hands it back through `arrived`
      @undo.on(:restored) { |id| emit(:fetch, id); emit(:restored, id) }
    end
  end
end
