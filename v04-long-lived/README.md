# V04: A Long-Lived Composition (Rails)

V03 (`../v03-pure-core-streams`) with one open advance built: the cart page's composition is **not
rebuilt per request**. `ProgrammingParadigms::LongLived` keeps one `Screens::Cart` per cart in the
process, runs each request under that composition's own lock (Spray's arbitrator, §3.10.2, decided
where the instances are kept and never inside a class), and reloads the values only when the cart's
write stamp moved behind its back. Between requests the values hold the cart in memory; a change
works on what they hold and answers with its patches; a GET renders what they hold. `DESIGN.md`
records the change, what it costs, and the hand walk.

**Status:** 66 integration tests (V03's 57, plus 5 of the execution model and 4 of the long-lived
cart) and 5 Cuprite browser tests, 0 failures; RuboCop clean;
`../../ala_lint_ruby/bin/ala_lint --root . --super-strict` scores it **100/100** with six accepted
lines (`--list-accepted` prints them: the locks in the execution model and the write stamp in the
models). `LINT_NOTES.md` has the run.

## Run it

```bash
cd v04-long-lived             # asdf picks Ruby 4.0.7 from .ruby-version
bin/rails db:prepare db:seed  # Postgres at localhost, user postgres/postgres (see config/database.yml)
bin/dev                       # http://localhost:3000
bin/rails test
```

## What's where

| Layer | Directory | Holds |
|---|---|---|
| Application | `app/ala/screens/`, `app/controllers/`, `app/views/{products,carts,checkouts,portals,...}`, `config/routes.rb` | `Screens::Store` (the calibration: rates, codes, tiers, words); one screen per page that builds, configures and wires instances (the cart's once per cart and kept, the others per request); controllers that push one input and redirect or render; page templates that place components |
| Domain abstractions | `app/ala/domain_abstractions/`, `app/views/components/` | `CartLines`, `SavedItems`, `Wishlist` (values), `CartItemsStore`, `SavedItemsStore`, `WishlistStore` (their stores), `Undo`, `ProductIndex`, `PricingChoices`, `CartTotals`, `OrderTotals`, `CheckoutFlow`, `SubmitOrder`, `Records`, `AddLine`, `Charge`, `SettleOrder`; the domain UI partials that take projected rows and words: `cart_line`, `saved_line`, `wishlist_line`, `order_line`, `catalog_order_row`, `product_row`, `cart_summary`, `shipping_selector`, `promo_form`, `checkout_status` |
| Rules | `app/ala/rules/`, `app/views/elements/` | the pure rules and projections (`Pricing`, `CalculateShipping`, `CalculateGiftWrapCost`, `ValidatePromo`, `VolumeTier`, `StockStatus`, `CheckStock`, `BuildLineItems`, `ProductRow`); the generic UI elements (`product_line`, `stock_badge`, `record_form`, `modal`, `tabs`, `milestones`, `notice_with_action`, `flash`, `none`) |
| Programming paradigms | `app/ala/programming_paradigms/` | `DataFlow`, `Event`, `RequestResponse` (each builds its port objects), `Transitions` (the state-machine table), `LiveUpdate` (a Turbo Stream broadcast sink), `Patches` and `Patch` (a Turbo Stream response built from outputs), `PushLater` (an Active Job that rebuilds a screen and pushes an input), `LongLived` (one kept composition per key, one thread at a time, reloaded when the store's stamp moved) |
| Foundation | `app/ala/foundation/`, `app/models/`, `app/javascript/controllers/` | `Ports` (ports and wiring), `Money`, `DomTargets` (the DOM names live updates target, declared as a view helper), `LedgerGateway`; the Active Record models as persistence, one per feature; five small Stimulus controllers |

Each feature keeps its own table against the cart's identity (R10): `cart_items` (the lines both
the storefront and the portal build on), `saved_items`, `wishlist_items`, `cart_pricing_choices`,
`checkouts`, `order_submissions`, `orders`. The line tables hold a `product_id` and no association:
what a product looks like comes through a `products` port the screen wires to one `ProductIndex`.

## How a request runs

```ruby
class CartItemsController < ApplicationController
  def destroy
    change { _1.input_port(:remove).push(params[:id].to_i) }   # one input, on the cart's kept screen
  end
end
```

`change` runs its block inside `Rails.configuration.x.cart_screens.with(cart_id)`: the registry
hands it the cart's composition (built by `Screens::Cart.new(cart_id:)` the first time), reloaded
if the cart's `version` moved since the composition last used it, with its flash and patches
cleared; then answers with the patches the outputs made. `Screens::Cart.new` builds the page's
instances, configures them from `Screens::Store`, and wires them: `@lines.wire_to(@undo, from: :removed, to: :capture)`, `@undo.on(:restored) { say
:notice, "Item restored" }`. Data moves between instances through their ports; the screen keeps only
what lands (`@totals.on(:summary) { @summary = _1 }`), and the view reads it. See `DESIGN.md`.
