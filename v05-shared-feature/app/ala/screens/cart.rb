module Screens
  # The cart page: the lines, the undo offer, items saved for later, the wishlist, the promo code and
  # shipping choice, and the priced summary. Built once per cart and kept (see `LongLived`): the
  # values hold the cart between requests and reload only when the store's stamp moved. On a GET the
  # controller renders what the values hold; on a change it answers with the patches the outputs
  # made, so the page is never rebuilt in the browser or on the server. The wiring is the `wire_to`
  # and `on` lines below. The lines and their undo are one feature, `Features::OrderLines`, that the
  # portal page places too.
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

    def parts = { order: @order, saved: @saved, wishlist: @wishlist, pricing: @pricing, totals: @totals, products: @products,
                  items: @items, saved_store: @saved_store, wishlist_store: @wishlist_store, feed: @feed }
    def live = @feed.subscription

    # Lives across requests: `reload` reads the stores again, `show` says what it holds, `begin` opens
    # a request with an empty flash and no patches, and each change works on what it holds.
    input(:reload, ProgrammingParadigms::Event) do
      @wishlist.input_port(:load).send_event
      @saved.input_port(:load).send_event
      @pricing.input_port(:load).send_event
      @order.input_port(:load).send_event
    end
    input(:show, ProgrammingParadigms::Event) do
      @wishlist.input_port(:show).send_event
      @saved.input_port(:show).send_event
      @order.input_port(:show).send_event
    end
    input(:begin, ProgrammingParadigms::Event) { @flash = {}; @patches.clear }
    input(:bump, ProgrammingParadigms::DataFlow) { |change| @order.input_port(:bump).push(change) }
    input(:remove, ProgrammingParadigms::DataFlow) { |item_id| @order.input_port(:remove).push(item_id) }
    input(:undo, ProgrammingParadigms::Event) { @order.input_port(:undo).send_event }
    input(:expire_undo, ProgrammingParadigms::Event) { @order.input_port(:expire_undo).send_event }
    input(:toggle_gift_wrap, ProgrammingParadigms::DataFlow) { |item_id| @order.input_port(:toggle_gift_wrap).push(item_id) }
    input(:save_for_later, ProgrammingParadigms::DataFlow) { |item_id| @order.input_port(:save_for_later).push(item_id) }
    input(:move_to_cart, ProgrammingParadigms::DataFlow) { |saved_id| @saved.input_port(:move_to_cart).push(saved_id) }
    input(:toggle_wishlist, ProgrammingParadigms::DataFlow) { |item_id| @order.input_port(:line).push(item_id) }
    input(:remove_wishlisted, ProgrammingParadigms::DataFlow) { |product_id| @wishlist.input_port(:remove).push(product_id) }
    input(:add_wishlisted, ProgrammingParadigms::DataFlow) { |product_id| @wishlist.input_port(:take).push(product_id) }
    input(:enter_promo, ProgrammingParadigms::DataFlow) { |code| @pricing.input_port(:enter_promo).push(code) }
    input(:select_shipping, ProgrammingParadigms::DataFlow) { |method| @pricing.input_port(:select_shipping).push(method) }
    input(:live, ProgrammingParadigms::DataFlow) { |message| @feed.input_port(:receive).push(message) }

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
      @order = Features::OrderLines.new(cart_id:, undo_lines: CartItem, undo_window: Store::UNDO_WINDOW,
                                        row: LineRow.new(fields: %i[name thumbnail amount stock stock_status],
                                                         links: ->(id) { { quantity: urls.cart_item_path(id), remove: urls.cart_item_path(id),
                                                                           gift_wrap: urls.gift_wrap_cart_item_path(id), save: urls.save_cart_item_path(id),
                                                                           wishlist: urls.wishlist_cart_item_path(id) } }))
      @saved = SavedItems.new(cart_id:, row: LineRow.new(fields: %i[name thumbnail amount], links: ->(id) { { move: urls.move_cart_saved_item_path(id) } }))
      @wishlist = Wishlist.new(cart_id:, row: LineRow.new(fields: %i[name thumbnail amount],
                                                          links: ->(id) { { add: urls.add_to_cart_cart_wishlist_item_path(id), remove: urls.cart_wishlist_item_path(id) } }))
      @pricing = PricingChoices.new(store: CartPricingChoice, cart_id:, shipping:, default_method: :standard,
                                    promo: ValidatePromo.new(codes: Store::PROMO_CODES))
      @totals = CartTotals.new(shipping:, gift_wrap: CalculateGiftWrapCost.new(unit: Store::GIFT_WRAP_CENTS))
      @feed = ProgrammingParadigms::ChangeFeed::Subscription.new(topic: Store::CATALOG_TOPIC, kinds: %i[stock product])

      # the order's lines: pulled from the store, changed in memory, written back through `changed`
      @order.wire_to(@items, from: :items, to: :lookup)
      @order.wire_to(@products, from: :products, to: :lookup)
      @order.wire_to(@items, from: :changed, to: :apply)
      @order.wire_to(@items, from: :adding, to: :add)
      @order.wire_to(@items, from: :fetch, to: :fetch)
      @items.wire_to(@order, from: :added, to: :arrived)
      @items.wire_to(@order, from: :found, to: :arrived)
      @order.on(:rows) { @rows = _1 }
      @order.wire_to(@totals, from: :contents, to: :contents)
      @order.wire_to(@saved, from: :saved, to: :stash)
      @order.on(:saved) { notice say[:saved] }
      @order.on(:line) { |line| @wishlist.input_port(:toggle).push(line[:product_id]) }
      # each line change is one patch of the page
      wishlist_ids = -> { @wishlist_ids }
      line_html = ->(row) { Partial.render("components/cart_line", row:, wishlist_ids: wishlist_ids.(), t: t[:cart], labels:) }
      @order.wire_to(patch(:append, dom.items_pane_id, line_html), from: :row_added)
      @order.wire_to(patch(:replace, ->(row) { dom.cart_line_id(row[:id]) }, line_html), from: :row_changed)
      @order.wire_to(patch(:remove, ->(row) { dom.cart_line_id(row[:id]) }), from: :row_removed)

      @order.on(:undo_pending) { @undo_pending = _1 }
      @order.wire_to(patch(:update, dom.undo_id, ->(shown) { Partial.render("elements/notice_with_action", shown:, text: t[:undo][:text], action: t[:undo][:undo],
                                                                                url: urls.cart_undo_path, expire_url: urls.expire_cart_undo_path, after_ms: Store::UNDO_WINDOW.in_milliseconds) }),
                     from: :undo_pending)
      @order.on(:restored) { notice say[:restored] }

      # saved for later: pulled, changed in memory, written back; its pane is one patch
      @saved.wire_to(@saved_store, from: :items, to: :lookup)
      @saved.wire_to(@products, from: :products, to: :lookup)
      @saved.wire_to(@saved_store, from: :changed, to: :apply)
      @saved.on(:rows) { @saved_rows = _1 }
      @saved.on(:count) { @saved_count = _1 }
      @saved.wire_to(patch(:update, dom.saved_pane_id, ->(rows) { Partial.render("elements/pane", rows:, item: "components/saved_line", t: t[:saved]) }), from: :rows_changed)
      @saved.wire_to(@order, from: :moved, to: :receive)
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
      @wishlist.wire_to(@order, from: :taken, to: :receive)
      @wishlist.on(:taken) { notice say[:added] }

      @pricing.wire_to(@totals, from: :discount, to: :discount)
      @pricing.wire_to(@totals, from: :shipping_method, to: :shipping_method)
      @pricing.on(:promo_applied) { notice say[:promo_applied] }
      @pricing.on(:promo_rejected) { @flash[:alert] = say[:promo_rejected]; @flash[:promo_error] = say[:promo_rejected] }

      # a product changed elsewhere: the lists that hold it ask for it again and patch their rows
      @feed.wire_to(@order, from: :stock, to: :product)
      @feed.wire_to(@order, from: :product, to: :product)
      @feed.wire_to(@saved, from: :product, to: :product)
      @feed.wire_to(@wishlist, from: :product, to: :product)

      # the summary and the tab counts follow every change
      @totals.on(:summary) { @summary = _1 }
      @totals.wire_to(patch(:update, dom.summary_id, ->(summary) { Partial.render("components/cart_summary", summary:, t: t[:cart]) }), from: :summary)
      @totals.wire_to(patch(:update, dom.tabs_id, ->(summary) { Partial.render("elements/tabs", tabs: tabs(summary)) }), from: :summary)
      @totals.wire_to(patch(:update, dom.shipping_selector_id, ->(summary) { Partial.render("components/shipping_selector", summary:, heading: t[:cart][:shipping], free_over: t[:cart][:free_over], url: urls.shipping_cart_path) }), from: :summary)
      @totals.wire_to(patch(:update, dom.promo_form_id, ->(summary) { Partial.render("components/promo_form", code: summary[:promo_code], error: @flash[:promo_error], url: urls.promo_cart_path, t: t[:cart]) }), from: :summary)
      @totals.wire_to(patch(:update, dom.empty_note_id, ->(summary) { Partial.render("elements/none", count: summary[:item_count], text: t[:cart][:empty]) }), from: :summary)
      @totals.wire_to(patch(:update, dom.checkout_button_id, ->(summary) { Partial.render("components/checkout_button", summary:, label: t[:cart][:checkout], url: urls.cart_checkout_path) }), from: :summary)
    end

    def tabs(summary = @summary)
      [ [ :items, TEXTS[:tabs][:items], summary[:item_count] ], [ :saved, TEXTS[:tabs][:saved], @saved_count ], [ :wishlist, TEXTS[:tabs][:wishlist], @wishlist_count ] ]
    end

    private

    def notice(text) = @flash[:notice] = [ @flash[:notice], text ].compact.join(" ")
    def patch(action, target, render = nil) = ProgrammingParadigms::Patch.new(patches: @patches, action:, target:, render:)
  end
end
