module Screens
  # The cart page: the lines, the undo offer, items saved for later, the wishlist, the promo code and
  # shipping choice, and the priced summary. Built per request. On a GET the controller renders what
  # landed; on a change it answers with the patches the outputs made, so the page is never rebuilt
  # in the browser. The state abstractions are values: they pull their lines through ports and send
  # every change out to the stores wired here. The wiring is the `wire_to` and `on` lines below.
  class Cart
    include Foundation::Ports
    include DomainAbstractions
    include Rules

    TEXTS = {
      tabs: { items: "Items", saved: "Saved", wishlist: "Wishlist" },
      cart: { empty: "Your cart is empty.", checkout: "Checkout", discount: "Discount", gift_wrap: "Gift wrap",
              promo_placeholder: "Promo code", apply: "Apply", free_over: "free over", each: " each",
              save: "Save for later", wishlisted: "♥ Wishlisted", wishlist: "♡ Wishlist", remove: "Remove",
              gift_wrap_label: "Gift wrap (#{Foundation::Money[Store::GIFT_WRAP_CENTS]})" }.merge(Store::SUMMARY_TEXTS),
      saved: { empty: "No saved items.", move: "Move to cart" },
      wishlist: { empty: "Your wishlist is empty.", add: "Add to cart", remove: "Remove" },
      undo: { text: "Item removed.", undo: "Undo" },
      notices: { saved: "Saved for later", restored: "Item restored", moved: "Moved to cart", wishlisted: "Added to wishlist",
                 unwishlisted: "Removed from wishlist", added: "Added to cart", promo_applied: "Promo applied!", promo_rejected: "Invalid promo code" }
    }.freeze

    attr_reader :config, :rows, :summary, :saved_rows, :saved_count, :wishlist_rows, :wishlist_count, :wishlist_ids,
                :undo_pending, :flash, :patches

    def parts = { lines: @lines, undo: @undo, saved: @saved, wishlist: @wishlist, pricing: @pricing, totals: @totals, products: @products,
                  items: @items, saved_store: @saved_store, wishlist_store: @wishlist_store }

    input(:load, ProgrammingParadigms::Event) { load }
    # every change loads first: the values start empty each request, and the patches need the whole page's state
    input(:bump, ProgrammingParadigms::DataFlow) { |change| load; @lines.input_port(:bump).push(change) }
    input(:remove, ProgrammingParadigms::DataFlow) { |item_id| load; @lines.input_port(:remove).push(item_id) }
    input(:undo, ProgrammingParadigms::Event) { load; @undo.input_port(:restore).send_event }
    input(:expire_undo, ProgrammingParadigms::Event) { load; @undo.input_port(:expire).send_event }
    input(:toggle_gift_wrap, ProgrammingParadigms::DataFlow) { |item_id| load; @lines.input_port(:toggle_gift_wrap).push(item_id) }
    input(:save_for_later, ProgrammingParadigms::DataFlow) { |item_id| load; @lines.input_port(:save_for_later).push(item_id) }
    input(:move_to_cart, ProgrammingParadigms::DataFlow) { |saved_id| load; @saved.input_port(:move_to_cart).push(saved_id) }
    input(:toggle_wishlist, ProgrammingParadigms::DataFlow) { |item_id| load; @lines.input_port(:line).push(item_id) }
    input(:remove_wishlisted, ProgrammingParadigms::DataFlow) { |product_id| load; @wishlist.input_port(:remove).push(product_id) }
    input(:add_wishlisted, ProgrammingParadigms::DataFlow) { |product_id| load; @wishlist.input_port(:take).push(product_id) }
    input(:enter_promo, ProgrammingParadigms::DataFlow) { |code| load; @pricing.input_port(:enter_promo).push(code) }
    input(:select_shipping, ProgrammingParadigms::DataFlow) { |method| load; @pricing.input_port(:select_shipping).push(method) }

    def initialize(cart_id:)
      @config = { cart_id: }
      @flash = {}
      @patches = ProgrammingParadigms::Patches.new
      urls = Rails.application.routes.url_helpers
      shipping = CalculateShipping.new(rates: Store::RATES)
      say = TEXTS[:notices]
      labels = Store::STOCK_LABELS
      t = TEXTS
      dom = Foundation::DomTargets

      @products = ProductIndex.new(model: Product, project: ProductRow.new(stock_rule: StockStatus.new(low_at: Store::LOW_STOCK_AT)))
      @items = CartItemsStore.new(model: CartItem, cart_id:)
      @saved_store = SavedItemsStore.new(model: SavedItem, cart_id:)
      @wishlist_store = WishlistStore.new(model: WishlistItem, cart_id:)
      @lines = CartLines.new(cart_id:, links: ->(id) { { quantity: urls.cart_item_path(id), remove: urls.cart_item_path(id),
                                                        gift_wrap: urls.gift_wrap_cart_item_path(id), save: urls.save_cart_item_path(id),
                                                        wishlist: urls.wishlist_cart_item_path(id) } })
      @undo = Undo.new(lines: CartItem, cart_id:, window: Store::UNDO_WINDOW)
      @saved = SavedItems.new(cart_id:, links: ->(id) { { move: urls.move_cart_saved_item_path(id) } })
      @wishlist = Wishlist.new(cart_id:, links: ->(id) { { add: urls.add_to_cart_cart_wishlist_item_path(id), remove: urls.cart_wishlist_item_path(id) } })
      @pricing = PricingChoices.new(store: CartPricingChoice, cart_id:, shipping:, default_method: :standard,
                                    promo: ValidatePromo.new(codes: Store::PROMO_CODES))
      @totals = CartTotals.new(shipping:, gift_wrap: CalculateGiftWrapCost.new(unit: Store::GIFT_WRAP_CENTS))

      # the lines: pulled from the store, changed in memory, written back through `changed`
      @lines.wire_to(@items, from: :items, to: :lookup)
      @lines.wire_to(@products, from: :products, to: :lookup)
      @lines.wire_to(@items, from: :changed, to: :apply)
      @lines.wire_to(@items, from: :adding, to: :add)
      @items.wire_to(@lines, from: :added, to: :arrived)
      @lines.on(:rows) { @rows = _1 }
      @lines.wire_to(@totals, from: :contents, to: :contents)
      @lines.wire_to(@undo, from: :removed, to: :capture)
      @lines.wire_to(@saved, from: :saved, to: :stash)
      @lines.on(:saved) { notice say[:saved] }
      @lines.on(:line) { |line| @wishlist.input_port(:toggle).push(line[:product_id]) }
      # each line change is one patch of the page
      wishlist_ids = -> { @wishlist_ids }
      line_html = ->(row) { Partial.render("components/cart_line", row:, wishlist_ids: wishlist_ids.(), t: t[:cart], labels:) }
      @lines.wire_to(patch(:append, dom.items_pane_id, line_html), from: :row_added)
      @lines.wire_to(patch(:replace, ->(row) { dom.cart_line_id(row[:id]) }, line_html), from: :row_changed)
      @lines.wire_to(patch(:remove, ->(row) { dom.cart_line_id(row[:id]) }), from: :row_removed)

      @undo.on(:pending) { @undo_pending = _1 }
      @undo.wire_to(patch(:update, dom.undo_id, ->(shown) { Partial.render("elements/notice_with_action", shown:, text: t[:undo][:text], action: t[:undo][:undo],
                                                                               url: urls.cart_undo_path, expire_url: urls.expire_cart_undo_path, after_ms: Store::UNDO_WINDOW.in_milliseconds) }),
                    from: :pending)
      @undo.on(:restored) { notice say[:restored] }

      # saved for later: pulled, changed in memory, written back; its pane is one patch
      @saved.wire_to(@saved_store, from: :items, to: :lookup)
      @saved.wire_to(@products, from: :products, to: :lookup)
      @saved.wire_to(@saved_store, from: :changed, to: :apply)
      @saved.on(:rows) { @saved_rows = _1 }
      @saved.on(:count) { @saved_count = _1 }
      @saved.wire_to(patch(:update, dom.saved_pane_id, ->(rows) { Partial.render("elements/pane", rows:, item: "components/saved_line", t: t[:saved]) }), from: :rows_changed)
      @saved.wire_to(@lines, from: :moved, to: :receive)
      @saved.on(:moved) { notice say[:moved] }

      # the wishlist, the same way
      @wishlist.wire_to(@wishlist_store, from: :items, to: :lookup)
      @wishlist.wire_to(@products, from: :products, to: :lookup)
      @wishlist.wire_to(@wishlist_store, from: :changed, to: :apply)
      @wishlist.on(:rows) { @wishlist_rows = _1 }
      @wishlist.on(:count) { @wishlist_count = _1 }
      @wishlist.on(:ids) { @wishlist_ids = _1 }
      @wishlist.wire_to(patch(:update, dom.wishlist_pane_id, ->(rows) { Partial.render("elements/pane", rows:, item: "components/wishlist_line", t: t[:wishlist]) }), from: :rows_changed)
      @wishlist.on(:added) { notice say[:wishlisted] }
      @wishlist.on(:dropped) { notice say[:unwishlisted] }
      @wishlist.wire_to(@lines, from: :taken, to: :receive)
      @wishlist.on(:taken) { notice say[:added] }

      @pricing.wire_to(@totals, from: :discount, to: :discount)
      @pricing.wire_to(@totals, from: :shipping_method, to: :shipping_method)
      @pricing.on(:promo_applied) { notice say[:promo_applied] }
      @pricing.on(:promo_rejected) { @flash[:alert] = say[:promo_rejected]; @flash[:promo_error] = say[:promo_rejected] }

      # the summary and the tab counts follow every change
      @totals.on(:summary) { @summary = _1 }
      @totals.wire_to(patch(:update, dom.summary_id, ->(summary) { Partial.render("components/cart_summary", summary:, t: t[:cart]) }), from: :summary)
      @totals.wire_to(patch(:update, dom.tabs_id, ->(summary) { Partial.render("elements/tabs", tabs: tabs(summary)) }), from: :summary)
      @totals.wire_to(patch(:update, dom.shipping_selector_id, ->(summary) { Partial.render("components/shipping_selector", summary:, heading: t[:cart][:shipping], free_over: t[:cart][:free_over], url: urls.shipping_cart_path) }), from: :summary)
      @totals.wire_to(patch(:update, dom.promo_form_id, ->(summary) { Partial.render("components/promo_form", code: summary[:promo_code], error: @flash[:promo_error], url: urls.promo_cart_path, t: t[:cart]) }), from: :summary)
      @totals.wire_to(patch(:update, dom.empty_note_id, ->(summary) { Partial.render("elements/none", count: summary[:item_count], text: t[:cart][:empty]) }), from: :summary)
    end

    def tabs(summary = @summary)
      [ [ :items, TEXTS[:tabs][:items], summary[:item_count] ], [ :saved, TEXTS[:tabs][:saved], @saved_count ], [ :wishlist, TEXTS[:tabs][:wishlist], @wishlist_count ] ]
    end

    private

    def load
      @undo.input_port(:load).send_event
      @wishlist.input_port(:load).send_event
      @saved.input_port(:load).send_event
      @pricing.input_port(:load).send_event
      @lines.input_port(:load).send_event
    end
    def notice(text) = @flash[:notice] = [ @flash[:notice], text ].compact.join(" ")
    def patch(action, target, render = nil) = ProgrammingParadigms::Patch.new(patches: @patches, action:, target:, render:)
  end
end
