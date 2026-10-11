# V03: Pure Core and Streams (Rails)

V02 (`../v02-wired-rows`) with two things borrowed from the Elixir variants (V50, V51): the state
abstractions are **values** that pull their lines through ports and send every change out to a store
the screen wires, so the domain runs and tests without Postgres; and a change on the cart page
answers a Turbo request with the **patches** its outputs made instead of a redirect, so the page is
never rebuilt in the browser (R8.1 as written). `DESIGN.md` records the change and the hand walk.

**Status:** 57 integration tests (V02's 50, plus 4 stream-response tests and 3 store-free tests of the
pure core) and 5 Cuprite browser tests, 0 failures; RuboCop clean;
`../../ala_lint_ruby/bin/ala_lint --root . --super-strict` scores it **100/100 with no scored finding
at any tier** (238 functions). `LINT_NOTES.md` has the run.

## Run it

```bash
cd v03-pure-core-streams      # asdf picks Ruby 4.0.7 from .ruby-version
bin/rails db:prepare db:seed  # Postgres at localhost, user postgres/postgres (see config/database.yml)
bin/dev                       # http://localhost:3000
bin/rails test
```

## What's where

| Layer | Directory | Holds |
|---|---|---|
| Application | `app/ala/screens/`, `app/controllers/`, `app/views/{products,carts,checkouts,portals,...}`, `config/routes.rb` | `Screens::Store` (the calibration: rates, codes, tiers, words); one screen per page that builds, configures and wires instances per request; controllers that push one input and redirect or render; page templates that place components |
| Domain abstractions | `app/ala/domain_abstractions/`, `app/views/components/` | `CartLines`, `SavedItems`, `Wishlist` (values), `CartItemsStore`, `SavedItemsStore`, `WishlistStore` (their stores), `Undo`, `ProductIndex`, `PricingChoices`, `CartTotals`, `OrderTotals`, `CheckoutFlow`, `SubmitOrder`, `Records`, `AddLine`, `Charge`, `SettleOrder`; the domain UI partials that take projected rows and words: `cart_line`, `saved_line`, `wishlist_line`, `order_line`, `catalog_order_row`, `product_row`, `cart_summary`, `shipping_selector`, `promo_form`, `checkout_status` |
| Rules | `app/ala/rules/`, `app/views/elements/` | the pure rules and projections (`Pricing`, `CalculateShipping`, `CalculateGiftWrapCost`, `ValidatePromo`, `VolumeTier`, `StockStatus`, `CheckStock`, `BuildLineItems`, `ProductRow`); the generic UI elements (`product_line`, `stock_badge`, `record_form`, `modal`, `tabs`, `milestones`, `notice_with_action`, `flash`, `none`) |
| Programming paradigms | `app/ala/programming_paradigms/` | `DataFlow`, `Event`, `RequestResponse` (each builds its port objects), `Transitions` (the state-machine table), `LiveUpdate` (a Turbo Stream broadcast sink), `Patches` and `Patch` (a Turbo Stream response built from outputs), `PushLater` (an Active Job that rebuilds a screen and pushes an input) |
| Foundation | `app/ala/foundation/`, `app/models/`, `app/javascript/controllers/` | `Ports` (ports and wiring), `Money`, `DomTargets` (the DOM names live updates target, declared as a view helper), `LedgerGateway`; the Active Record models as persistence, one per feature; five small Stimulus controllers |

Each feature keeps its own table against the cart's identity (R10): `cart_items` (the lines both
the storefront and the portal build on), `saved_items`, `wishlist_items`, `cart_pricing_choices`,
`checkouts`, `order_submissions`, `orders`. The line tables hold a `product_id` and no association:
what a product looks like comes through a `products` port the screen wires to one `ProductIndex`.

## How a request runs

```ruby
class CartItemsController < ApplicationController
  def destroy
    screen.input_port(:remove).push(params[:id].to_i)   # one input
    back_to_cart                                         # redirect with what the screen said
  end
end
```

`Screens::Cart.new(cart_id:)` builds the page's instances, configures them from `Screens::Store`,
and wires them: `@lines.wire_to(@undo, from: :removed, to: :capture)`, `@undo.on(:restored) { say
:notice, "Item restored" }`. Data moves between instances through their ports; the screen keeps only
what lands (`@totals.on(:summary) { @summary = _1 }`), and the view reads it. See `DESIGN.md`.
