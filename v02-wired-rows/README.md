# V02: Wired Rows (Rails)

V01 (`../v01-wired-screens`) taken the rest of the way: the same storefront and B2B portal
(`ala_lab/docs/requirements-storefront-and-portal.md`), the same per-request screen compositions,
now with every edge dropping through a declared five-layer map, product data reaching the cart
through a pull port instead of an association, rows that carry their own URLs so pages render
collections with no logic, and names that flow down from the screens. `DESIGN.md` records what
changed and why, and the hand walk of the checklist.

**Status:** 48 tests, 0 failures (the same suite as V01, with the catalogue's broadcast and the
Records outputs updated). `../../ala_lint_ruby/bin/ala_lint --root . --super-strict` scores it
**100/100 with no scored finding at any tier** (204 functions, 204 clean); the two advisories left
are ratios it reports and never scores (the composition's share of functions, the average unit
size). `LINT_NOTES.md` says what the run shows and what it can't. Not yet exercised in a browser:
the integration tests cover the pages; the live paths (modal, countdown, payment redirect) were
checked by hand on V01 and the code they run is unchanged here.

## Run it

```bash
cd v02-wired-rows             # asdf picks Ruby 4.0.7 from .ruby-version
bin/rails db:prepare db:seed  # Postgres at localhost, user postgres/postgres (see config/database.yml)
bin/dev                       # http://localhost:3000
bin/rails test
```

## What's where

| Layer | Directory | Holds |
|---|---|---|
| Application | `app/ala/screens/`, `app/controllers/`, `app/views/{products,carts,checkouts,portals,...}`, `config/routes.rb` | `Screens::Store` (the calibration: rates, codes, tiers, words); one screen per page that builds, configures and wires instances per request; controllers that push one input and redirect or render; page templates that place components |
| Domain abstractions | `app/ala/domain_abstractions/`, `app/views/components/` | `CartLines`, `Undo`, `SavedItems`, `Wishlist`, `ProductIndex`, `PricingChoices`, `CartTotals`, `OrderTotals`, `CheckoutFlow`, `SubmitOrder`, `Records`, `AddLine`, `Charge`, `SettleOrder`; the domain UI partials that take projected rows and words: `cart_line`, `saved_line`, `wishlist_line`, `order_line`, `catalog_order_row`, `product_row`, `cart_summary`, `shipping_selector`, `promo_form`, `checkout_status` |
| Rules | `app/ala/rules/`, `app/views/elements/` | the pure rules and projections (`Pricing`, `CalculateShipping`, `CalculateGiftWrapCost`, `ValidatePromo`, `VolumeTier`, `StockStatus`, `CheckStock`, `BuildLineItems`, `ProductRow`); the generic UI elements (`product_line`, `stock_badge`, `record_form`, `modal`, `tabs`, `milestones`, `notice_with_action`, `flash`, `none`) |
| Programming paradigms | `app/ala/programming_paradigms/` | `DataFlow`, `Event`, `RequestResponse` (each builds its port objects), `Transitions` (the state-machine table), `LiveUpdate` (a Turbo Stream broadcast sink), `PushLater` (an Active Job that rebuilds a screen and pushes an input) |
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
