module Features
  # The lines of an order being edited, with a removal that can be undone for a while: Spray's
  # feature (§2.2), a composition of domain abstractions a page places as one part. Inside, a
  # `CartLines` value and an `Undo` are wired to each other in `wire`; what leaves is said with `out`
  # and returned to the page, which wires it to its store, its totals and its patches as it would any
  # part's outputs. Placed by the cart page and the portal page with different links and windows.
  # Config: cart_id, products (a lambda of product ids giving rows), links (a lambda of the item id
  # giving a row's URLs), undo_lines (the store Undo marks), undo_window (a duration).
  # In: load (the stored lines), lines (answers { cart_id:, lines: }), bump, set_quantity, remove,
  # save_for_later, toggle_gift_wrap, line, receive, arrived, undo, expire_undo.
  # Out: changed and adding (for the lines store), rows, row_added, row_changed, row_removed,
  # contents, saved, line, undo_pending, restored.
  class OrderLines
    include ProgrammingParadigms::Wiring
    OUTPUTS = %i[changed adding rows row_added row_changed row_removed contents saved line undo_pending restored].freeze
    GROUNDED = [].freeze

    def parts = { lines: @lines, undo: @undo }

    def load(items) = collect { run(:undo, @undo.load); run(:lines, @lines.load(items)) }
    def lines = @lines.lines
    def bump(change) = collect { run(:lines, @lines.bump(change)) }
    def set_quantity(change) = collect { run(:lines, @lines.set_quantity(change)) }
    def remove(item_id) = collect { run(:lines, @lines.remove(item_id)) }
    def save_for_later(item_id) = collect { run(:lines, @lines.save_for_later(item_id)) }
    def toggle_gift_wrap(item_id) = collect { run(:lines, @lines.toggle_gift_wrap(item_id)) }
    def line(item_id) = collect { run(:lines, @lines.line(item_id)) }
    def receive(request) = collect { run(:lines, @lines.receive(request)) }
    def arrived(item) = collect { run(:lines, @lines.arrived(item)) }
    def undo = collect { run(:undo, @undo.restore) }
    def expire_undo = collect { run(:undo, @undo.expire) }

    def initialize(cart_id:, products:, links:, undo_lines:, undo_window:)
      @lines = DomainAbstractions::CartLines.new(cart_id:, products:, links:)
      @undo = DomainAbstractions::Undo.new(lines: undo_lines, cart_id:, window: undo_window)
    end

    private

    # {part, output} → wired inside, or out of this feature
    def wire(part, output, payload)
      case [ part, output ]
      in [ :lines, :removed ] then run(:undo, @undo.capture(payload))
      in [ :undo, :pending ] then out(:undo_pending, payload)
      in [ :lines, _ ] | [ :undo, _ ] then out(output, payload)
      end
    end
  end
end
