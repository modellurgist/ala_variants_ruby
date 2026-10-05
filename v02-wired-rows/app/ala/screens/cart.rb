module Screens
  # The cart page: the lines, the undo offer, items saved for later, the wishlist, the promo code and
  # shipping choice, and the priced summary. Built per request; the controller pushes one input, then
  # redirects with what the screen says, or renders what landed. The wiring between the parts is the
  # `wire_to` and `on` lines below, read top to bottom.
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
                :undo_pending, :flash

    def parts = { lines: @lines, undo: @undo, saved: @saved, wishlist: @wishlist, pricing: @pricing, totals: @totals, products: @products }

    input(:load, ProgrammingParadigms::Event) do
      [ @undo, @lines, @pricing, @saved, @wishlist ].each { _1.input_port(:load).send_event }
    end
    input(:bump, ProgrammingParadigms::DataFlow) { |change| @lines.input_port(:bump).push(change) }
    input(:remove, ProgrammingParadigms::DataFlow) { |item_id| @lines.input_port(:remove).push(item_id) }
    input(:undo, ProgrammingParadigms::Event) { @undo.input_port(:restore).send_event }
    input(:expire_undo, ProgrammingParadigms::Event) { @undo.input_port(:expire).send_event }
    input(:toggle_gift_wrap, ProgrammingParadigms::DataFlow) { |item_id| @lines.input_port(:toggle_gift_wrap).push(item_id) }
    input(:save_for_later, ProgrammingParadigms::DataFlow) { |item_id| @lines.input_port(:save_for_later).push(item_id) }
    input(:move_to_cart, ProgrammingParadigms::DataFlow) { |saved_id| @saved.input_port(:move_to_cart).push(saved_id) }
    input(:toggle_wishlist, ProgrammingParadigms::DataFlow) { |item_id| @lines.input_port(:line).push(item_id) }
    input(:remove_wishlisted, ProgrammingParadigms::DataFlow) { |product_id| @wishlist.input_port(:remove).push(product_id) }
    input(:add_wishlisted, ProgrammingParadigms::DataFlow) { |product_id| @wishlist.input_port(:take).push(product_id) }
    input(:enter_promo, ProgrammingParadigms::DataFlow) { |code| @pricing.input_port(:enter_promo).push(code) }
    input(:select_shipping, ProgrammingParadigms::DataFlow) { |method| @pricing.input_port(:select_shipping).push(method) }

    def initialize(cart_id:)
      @config = { cart_id: }
      @flash = {}
      urls = Rails.application.routes.url_helpers
      shipping = CalculateShipping.new(rates: Store::RATES)
      say = TEXTS[:notices]

      @products = ProductIndex.new(model: Product, project: ProductRow.new(stock_rule: StockStatus.new(low_at: Store::LOW_STOCK_AT)))
      @lines = CartLines.new(lines: CartItem, cart_id:, links: ->(id) { { quantity: urls.cart_item_path(id), remove: urls.cart_item_path(id),
                                                                           gift_wrap: urls.gift_wrap_cart_item_path(id), save: urls.save_cart_item_path(id),
                                                                           wishlist: urls.wishlist_cart_item_path(id) } })
      @undo = Undo.new(lines: CartItem, cart_id:, window: Store::UNDO_WINDOW)
      @saved = SavedItems.new(store: SavedItem, cart_id:, links: ->(id) { { move: urls.move_cart_saved_item_path(id) } })
      @wishlist = Wishlist.new(store: WishlistItem, cart_id:, links: ->(id) { { add: urls.add_to_cart_cart_wishlist_item_path(id), remove: urls.cart_wishlist_item_path(id) } })
      @pricing = PricingChoices.new(store: CartPricingChoice, cart_id:, shipping:, default_method: :standard,
                                    promo: ValidatePromo.new(codes: Store::PROMO_CODES))
      @totals = CartTotals.new(shipping:, gift_wrap: CalculateGiftWrapCost.new(unit: Store::GIFT_WRAP_CENTS))

      @lines.wire_to(@products, from: :products, to: :lookup)
      @lines.on(:rows) { @rows = _1 }
      @lines.wire_to(@totals, from: :contents, to: :contents)
      @lines.wire_to(@undo, from: :removed, to: :capture)
      @lines.wire_to(@saved, from: :saved, to: :stash)
      @lines.on(:saved) { notice say[:saved] }
      @lines.on(:line) { |line| @wishlist.input_port(:toggle).push(line[:product_id]) }

      @undo.on(:pending) { @undo_pending = _1 }
      @undo.on(:restored) { notice say[:restored] }

      @saved.wire_to(@products, from: :products, to: :lookup)
      @saved.on(:rows) { @saved_rows = _1 }
      @saved.on(:count) { @saved_count = _1 }
      @saved.wire_to(@lines, from: :moved, to: :receive)
      @saved.on(:moved) { notice say[:moved] }

      @wishlist.wire_to(@products, from: :products, to: :lookup)
      @wishlist.on(:rows) { @wishlist_rows = _1 }
      @wishlist.on(:count) { @wishlist_count = _1 }
      @wishlist.on(:ids) { @wishlist_ids = _1 }
      @wishlist.on(:added) { notice say[:wishlisted] }
      @wishlist.on(:dropped) { notice say[:unwishlisted] }
      @wishlist.wire_to(@lines, from: :taken, to: :receive)
      @wishlist.on(:taken) { notice say[:added] }

      @pricing.wire_to(@totals, from: :discount, to: :discount)
      @pricing.wire_to(@totals, from: :shipping_method, to: :shipping_method)
      @pricing.on(:promo_applied) { notice say[:promo_applied] }
      @pricing.on(:promo_rejected) { @flash[:alert] = say[:promo_rejected]; @flash[:promo_error] = say[:promo_rejected] }

      @totals.on(:summary) { @summary = _1 }
    end

    private

    def notice(text) = @flash[:notice] = [ @flash[:notice], text ].compact.join(" ")
  end
end
