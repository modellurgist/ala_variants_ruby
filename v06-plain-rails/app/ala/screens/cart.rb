module Screens
  # The cart page: the lines, the undo offer, items saved for later, the wishlist, the promo code and
  # shipping choice, and the priced summary. Built per request. On a GET the controller renders what
  # landed; on a change it answers with the patches the arms made, so the page is never rebuilt in
  # the browser. The state abstractions are values: the composition hands them their stored lines and
  # writes every change they decide to the stores. The wiring is the `wire` method: one arm per
  # output of each part, read top to bottom.
  class Cart
    include ProgrammingParadigms::Wiring
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
    GROUNDED = [].freeze

    attr_reader :config, :rows, :summary, :saved_rows, :saved_count, :wishlist_rows, :wishlist_count, :wishlist_ids,
                :undo_pending, :flash, :patches

    def parts = { lines: @lines, undo: @undo, saved: @saved, wishlist: @wishlist, pricing: @pricing, totals: @totals, items: @items,
                  saved_store: @saved_store, wishlist_store: @wishlist_store }

    # every change loads first: the values start empty each request, and the patches need the whole page's state
    def load
      run(:undo, @undo.load)
      run(:wishlist, @wishlist.load(@wishlist_store.lookup))
      run(:saved, @saved.load(@saved_store.lookup))
      run(:pricing, @pricing.load)
      run(:lines, @lines.load(@items.lookup))
    end
    def bump(change) = (load; run(:lines, @lines.bump(change)))
    def remove(item_id) = (load; run(:lines, @lines.remove(item_id)))
    def undo = (load; run(:undo, @undo.restore))
    def expire_undo = (load; run(:undo, @undo.expire))
    def toggle_gift_wrap(item_id) = (load; run(:lines, @lines.toggle_gift_wrap(item_id)))
    def save_for_later(item_id) = (load; run(:lines, @lines.save_for_later(item_id)))
    def move_to_cart(saved_id) = (load; run(:saved, @saved.move_to_cart(saved_id)))
    def toggle_wishlist(item_id) = (load; run(:lines, @lines.line(item_id)))
    def remove_wishlisted(product_id) = (load; run(:wishlist, @wishlist.remove(product_id)))
    def add_wishlisted(product_id) = (load; run(:wishlist, @wishlist.take(product_id)))
    def enter_promo(code) = (load; run(:pricing, @pricing.enter_promo(code)))
    def select_shipping(method) = (load; run(:pricing, @pricing.select_shipping(method)))

    def initialize(cart_id:)
      @config = { cart_id: }
      @flash = {}
      @patches = ProgrammingParadigms::Patches.new
      urls = Rails.application.routes.url_helpers
      shipping = CalculateShipping.new(rates: Store::RATES)
      @say = TEXTS[:notices]
      @t = TEXTS
      @dom = Foundation::DomTargets
      @urls = urls
      labels = Store::STOCK_LABELS

      products = ProductIndex.new(model: Product, project: ProductRow.new(stock_rule: StockStatus.new(low_at: Store::LOW_STOCK_AT)))
      lookup = ->(ids) { products.lookup(ids) }
      @items = CartItemsStore.new(model: CartItem, cart_id:)
      @saved_store = SavedItemsStore.new(model: SavedItem, cart_id:)
      @wishlist_store = WishlistStore.new(model: WishlistItem, cart_id:)
      @lines = CartLines.new(cart_id:, rows: LineRow.new(products: lookup,
                             links: ->(id) { { quantity: urls.cart_item_path(id), remove: urls.cart_item_path(id),
                                               gift_wrap: urls.gift_wrap_cart_item_path(id), save: urls.save_cart_item_path(id),
                                               wishlist: urls.wishlist_cart_item_path(id) } }))
      @undo = Undo.new(lines: CartItem, cart_id:, window: Store::UNDO_WINDOW)
      @saved = SavedItems.new(cart_id:, rows: LineRow.new(products: lookup, links: ->(id) { { move: urls.move_cart_saved_item_path(id) } }))
      @wishlist = Wishlist.new(cart_id:, rows: LineRow.new(products: lookup, links: ->(id) { { add: urls.add_to_cart_cart_wishlist_item_path(id), remove: urls.cart_wishlist_item_path(id) } }))
      @pricing = PricingChoices.new(store: CartPricingChoice, cart_id:, shipping:, default_method: :standard,
                                    promo: ValidatePromo.new(codes: Store::PROMO_CODES))
      @totals = CartTotals.new(shipping:, gift_wrap: CalculateGiftWrapCost.new(unit: Store::GIFT_WRAP_CENTS))
      @line_html = ->(row) { Partial.render("components/cart_line", row:, wishlist_ids: @wishlist_ids, t: @t[:cart], labels:) }
    end

    def tabs(summary = @summary)
      [ [ :items, TEXTS[:tabs][:items], summary[:item_count] ], [ :saved, TEXTS[:tabs][:saved], @saved_count ], [ :wishlist, TEXTS[:tabs][:wishlist], @wishlist_count ] ]
    end

    private

    # {part, output} → where it goes: another part, through `run`, or this page
    def wire(part, output, payload)
      case [ part, output ]
      # the lines: changed in memory, written back, each change one patch of the page
      in [ :lines, :changed ] then run(:items, @items.apply(payload))
      in [ :lines, :adding ] then run(:items, @items.add(payload))
      in [ :items, :added ] then run(:lines, @lines.arrived(payload))
      in [ :lines, :rows ] then @rows = payload
      in [ :lines, :contents ] then run(:totals, @totals.contents(payload))
      in [ :lines, :removed ] then run(:undo, @undo.capture(payload))
      in [ :lines, :saved ] then run(:saved, @saved.stash(payload)); notice @say[:saved]
      in [ :lines, :line ] then run(:wishlist, @wishlist.toggle(payload[:product_id]))
      in [ :lines, :row_added ] then @patches.append(@dom.items_pane_id, @line_html.(payload))
      in [ :lines, :row_changed ] then @patches.replace(@dom.cart_line_id(payload[:id]), @line_html.(payload))
      in [ :lines, :row_removed ] then @patches.remove(@dom.cart_line_id(payload[:id]))
      # the undo offer
      in [ :undo, :pending ] then @undo_pending = payload; @patches.update(@dom.undo_id, undo_html(payload))
      in [ :undo, :restored ] then run(:lines, @lines.arrived(@items.line(payload))); notice @say[:restored]
      # saved for later: written back, then reloaded for the ids the store gave; its pane is one patch
      in [ :saved, :changed ] then run(:saved_store, @saved_store.apply(payload)); run(:saved, @saved.reload(@saved_store.lookup))
      in [ :saved, :rows ] then @saved_rows = payload
      in [ :saved, :count ] then @saved_count = payload
      in [ :saved, :rows_changed ] then @patches.update(@dom.saved_pane_id, Partial.render("elements/pane", rows: payload, item: "components/saved_line", t: @t[:saved]))
      in [ :saved, :moved ] then run(:lines, @lines.receive(payload)); notice @say[:moved]
      # the wishlist, the same way
      in [ :wishlist, :changed ] then run(:wishlist_store, @wishlist_store.apply(payload))
      in [ :wishlist, :rows ] then @wishlist_rows = payload
      in [ :wishlist, :count ] then @wishlist_count = payload
      in [ :wishlist, :ids ] then @wishlist_ids = payload
      in [ :wishlist, :rows_changed ] then @patches.update(@dom.wishlist_pane_id, Partial.render("elements/pane", rows: payload, item: "components/wishlist_line", t: @t[:wishlist]))
      in [ :wishlist, :added ] then notice @say[:wishlisted]
      in [ :wishlist, :dropped ] then notice @say[:unwishlisted]
      in [ :wishlist, :taken ] then run(:lines, @lines.receive(payload)); notice @say[:added]
      # pricing choices feed the totals; the summary and the tab counts follow every change
      in [ :pricing, :discount ] then run(:totals, @totals.discount(payload))
      in [ :pricing, :shipping_method ] then run(:totals, @totals.shipping_method(payload))
      in [ :pricing, :promo_applied ] then notice @say[:promo_applied]
      in [ :pricing, :promo_rejected ] then @flash[:alert] = @say[:promo_rejected]; @flash[:promo_error] = @say[:promo_rejected]
      in [ :totals, :summary ]
        @summary = payload
        @patches.update(@dom.summary_id, Partial.render("components/cart_summary", summary: payload, t: @t[:cart]))
        @patches.update(@dom.tabs_id, Partial.render("elements/tabs", tabs: tabs(payload)))
        @patches.update(@dom.shipping_selector_id, Partial.render("components/shipping_selector", summary: payload, heading: @t[:cart][:shipping], free_over: @t[:cart][:free_over], url: @urls.shipping_cart_path))
        @patches.update(@dom.promo_form_id, Partial.render("components/promo_form", code: payload[:promo_code], error: @flash[:promo_error], url: @urls.promo_cart_path, t: @t[:cart]))
        @patches.update(@dom.empty_note_id, Partial.render("elements/none", count: payload[:item_count], text: @t[:cart][:empty]))
        @patches.update(@dom.checkout_button_id, Partial.render("components/checkout_button", summary: payload, label: @t[:cart][:checkout], url: @urls.cart_checkout_path))
      end
    end

    def undo_html(shown)
      Partial.render("elements/notice_with_action", shown:, text: @t[:undo][:text], action: @t[:undo][:undo],
                     url: @urls.cart_undo_path, expire_url: @urls.expire_cart_undo_path, after_ms: Store::UNDO_WINDOW.in_milliseconds)
    end

    def notice(text) = @flash[:notice] = [ @flash[:notice], text ].compact.join(" ")
  end
end
