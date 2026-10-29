module Screens
  # The cart page: the lines, the undo offer, items saved for later, the wishlist, the promo code and
  # shipping choice, and the priced summary. Built per request. On a GET the controller renders what
  # landed; on a change it answers with the patches the arms made, so the page is never rebuilt in
  # the browser. The state abstractions are values: the composition hands them their stored lines and
  # writes every change they decide to the stores. The wiring is the `wire` method: one arm per
  # output of each part, read top to bottom. The lines and their undo are one feature,
  # `Features::OrderLines`, that the portal page places too; it, the pricing choices, the totals and
  # the lines store are wired. Saved items and the wishlist are placed only here: the page holds each
  # as a list of products and calls it and its store.
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

    attr_reader :config, :rows, :summary, :undo_pending, :flash, :patches, :feed

    def parts = { order: @order, pricing: @pricing, totals: @totals, items: @items, feed: @feed }

    def saved_rows = @saved.rows
    def wishlist_rows = @wishlist.rows
    def wishlist_ids = @wishlist.entries

    # every change loads first: the values start empty each request, and the patches need the whole page's state
    def load
      @wishlist.load(@wishlist_store.lookup)
      @saved.load(@saved_store.lookup)
      run(:pricing, @pricing.load)
      run(:order, @order.load(@items.lookup))
    end
    def bump(change) = (load; run(:order, @order.bump(change)))
    def remove(item_id) = (load; run(:order, @order.remove(item_id)))
    def undo = (load; run(:order, @order.undo))
    def expire_undo = (load; run(:order, @order.expire_undo))
    def toggle_gift_wrap(item_id) = (load; run(:order, @order.toggle_gift_wrap(item_id)))
    def save_for_later(item_id) = (load; run(:order, @order.save_for_later(item_id)))
    def toggle_wishlist(item_id) = (load; run(:order, @order.line(item_id)))
    def enter_promo(code) = (load; run(:pricing, @pricing.enter_promo(code)))
    def select_shipping(method) = (load; run(:pricing, @pricing.select_shipping(method)))
    def live(message) = run(:feed, @feed.receive(message))

    def move_to_cart(saved_id)
      load
      line = @saved.find(saved_id).slice(:product_id, :quantity)
      @saved_store.remove(saved_id)
      saved_changed
      run(:order, @order.receive(line))
      notice @say[:moved]
    end

    def remove_wishlisted(product_id) = (load; unwishlist(product_id))

    # the line arrives while the product is still wishlisted, as it always has: its row shows the heart
    def add_wishlisted(product_id)
      load
      run(:order, @order.receive(product_id))
      notice @say[:added]
      unwishlist(product_id)
    end

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
      stock_rule = StockStatus.new(low_at: Store::LOW_STOCK_AT)

      products = ProductIndex.new(model: Product, project: ProductRow.new(stock_rule:))
      lookup = ->(ids) { products.lookup(ids) }
      @items = CartItemsStore.new(model: CartItem, cart_id:)
      @saved_store = SavedItemsStore.new(model: SavedItem, cart_id:)
      @wishlist_store = WishlistStore.new(model: WishlistItem, cart_id:)
      @order = Features::OrderLines.new(cart_id:, undo_lines: CartItem, undo_window: Store::UNDO_WINDOW,
                                        held: HeldProducts.new(products: lookup,
                                                               links: ->(id) { { quantity: urls.cart_item_path(id), remove: urls.cart_item_path(id),
                                                                                 gift_wrap: urls.gift_wrap_cart_item_path(id), save: urls.save_cart_item_path(id),
                                                                                 wishlist: urls.wishlist_cart_item_path(id) } }))
      @saved = HeldProducts.new(products: lookup, links: ->(id) { { move: urls.move_cart_saved_item_path(id) } })
      @wishlist = HeldProducts.new(products: lookup, id: ->(id) { id }, product_id: ->(id) { id },
                                   links: ->(id) { { add: urls.add_to_cart_cart_wishlist_item_path(id), remove: urls.cart_wishlist_item_path(id) } })
      @pricing = PricingChoices.new(store: CartPricingChoice, cart_id:, shipping:, default_method: :standard,
                                    promo: ValidatePromo.new(codes: Store::PROMO_CODES))
      @totals = CartTotals.new(shipping:, gift_wrap: CalculateGiftWrapCost.new(unit: Store::GIFT_WRAP_CENTS))
      @line_html = ->(row) { Partial.render("components/cart_line", row:, wishlist_ids: @wishlist.entries, t: @t[:cart], labels:) }
      @feed = ProgrammingParadigms::ChangeFeed::Subscription.new(topic: Store::CATALOG_TOPIC, kinds: %i[stock], url: urls.live_cart_path)
      @badge_html = ->(fact) { Partial.render("elements/stock_badge", product_id: fact[:product_id], status: stock_rule.(fact[:stock]), stock: fact[:stock], labels:) }
    end

    def tabs(summary = @summary)
      [ [ :items, TEXTS[:tabs][:items], summary[:item_count] ], [ :saved, TEXTS[:tabs][:saved], @saved.entries.size ], [ :wishlist, TEXTS[:tabs][:wishlist], @wishlist.entries.size ] ]
    end

    private

    # {part, output} → where it goes: another part, through `run`, or this page
    def wire(part, output, payload)
      case [ part, output ]
      # the order's lines: changed in memory, written back, each change one patch of the page
      in [ :order, :changed ] then run(:items, @items.apply(payload))
      in [ :order, :adding ] then run(:items, @items.add(payload))
      in [ :items, :added ] then run(:order, @order.arrived(payload))
      in [ :order, :rows ] then @rows = payload
      in [ :order, :contents ] then run(:totals, @totals.contents(payload))
      in [ :order, :saved ] then @saved_store.stash(payload); saved_changed; notice @say[:saved]
      in [ :order, :line ] then toggle_wishlisted(payload[:product_id])
      in [ :order, :row_added ] then @patches.append(@dom.items_pane_id, @line_html.(payload))
      in [ :order, :row_changed ] then @patches.replace(@dom.cart_line_id(payload[:id]), @line_html.(payload))
      in [ :order, :row_removed ] then @patches.remove(@dom.cart_line_id(payload[:id]))
      # the undo offer
      in [ :order, :undo_pending ] then @undo_pending = payload; @patches.update(@dom.undo_id, undo_html(payload))
      in [ :order, :restored ] then notice @say[:restored]
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
      # a stock level changed elsewhere: every badge of that product on the page
      in [ :feed, :stock ] then @patches.replace_all(@dom.stock_selector(payload[:product_id]), @badge_html.(payload))
      end
    end

    def undo_html(shown)
      Partial.render("elements/notice_with_action", shown:, text: @t[:undo][:text], action: @t[:undo][:undo],
                     url: @urls.cart_undo_path, expire_url: @urls.expire_cart_undo_path, after_ms: Store::UNDO_WINDOW.in_milliseconds)
    end

    # saved for later is written back, then reloaded for the ids the store gave; its pane is one patch
    def saved_changed
      @saved.load(@saved_store.lookup)
      @patches.update(@dom.saved_pane_id, Partial.render("elements/pane", rows: @saved.rows, item: "components/saved_line", t: @t[:saved]))
    end

    def toggle_wishlisted(product_id)
      if @wishlist.entries.include?(product_id)
        @wishlist.take(product_id); @wishlist_store.remove(product_id); notice @say[:unwishlisted]
      else
        @wishlist.add(product_id); @wishlist_store.add(product_id); notice @say[:wishlisted]
      end
      wishlist_changed
    end

    def unwishlist(product_id)
      @wishlist.take(product_id) if @wishlist.entries.include?(product_id)
      @wishlist_store.remove(product_id)
      wishlist_changed
    end

    def wishlist_changed = @patches.update(@dom.wishlist_pane_id, Partial.render("elements/pane", rows: @wishlist.rows, item: "components/wishlist_line", t: @t[:wishlist]))

    def notice(text) = @flash[:notice] = [ @flash[:notice], text ].compact.join(" ")
  end
end
