# V05: A Shared Feature (Rails)

V04 (`../v04-long-lived`) with Spray's Features layer (§2.2) placed between the application and the
domain abstractions, and one feature in it: `Features::OrderLines`, the lines of an order with a
removal that can be undone, **used by two pages**. The cart page places it inside its long-lived
composition with the storefront's links and a five-second window; the portal page places it per
request with the portal's links and a ten-second window. Inside the feature a `CartLines` value and
an `Undo` are wired to each other; outside, each page wires the feature's ports to its own store,
product index, totals and patches. `DESIGN.md` records the change, what it costs, and the hand walk.

Extended on 2026-10-11 with three more things (the design once called V06, kept in this variant):
the Foundation's `forward`, which makes a part's outputs a feature's in one line each; a **running
trace** (`Foundation::Trace`) that the test suite turns on, so after a full run every wire of every
screen must have carried something at least once and `docs/diagrams/running/` draws each screen with
the wires that did solid and the rest dotted; and the **checkout kept across requests** too, with
the payment job delivering `charge` into the kept composition through a registry it names.

**Status:** 108 integration tests (V04's 66, plus 3 of the feature on fakes, 1 the trace asked for,
13 unit tests of the abstractions extracted 2026-10-19, one for `CartLines#find`'s refusal, 5 for
the defect fixes below, 4 for product changes reaching kept carts, a net 1 for the stamp race:
two new, one of them replacing V04's test that asserted it, and 14 for the live paradigm below) and
9 Cuprite browser tests, 0 failures; after the full suite, **0 wires never carried anything**;
RuboCop clean; `../../ala_lint_ruby/bin/ala_lint --root . --super-strict` scores it
**100/100**, 10 of 10 rules, with ten accepted lines (303 functions). `LINT_NOTES.md` has the run. The drawings in
`docs/diagrams/` draw the feature as a subgraph with its own wires inside; those in
`docs/diagrams/running/` are the same graphs as the suite exercised them.

*Since 2026-10-19:* the 100s above include the linter's clone check (duplicated logic, R7). Its three
findings were each one concept written two or more times and are extracted, none accepted: the
product row a held line shows (`Rules::LineRow`, configured by the page with the fields its partial
reads and the links), the priced summary's figures (`Rules::Pricing.summary`, which `CartTotals` and
`OrderTotals` extend), and the step machine kept in a record (`ProgrammingParadigms::PersistedSteps`,
built by the checkout and portal pages with their tables and handed to their flows). The two
`clone_inside` reports (in `Ports` and `Drawing`) are unscored and left alone.

*Defect fixes, 2026-10-19,* ported from V07 with their tests written first (V07's first, a restored
line not re-appearing over Turbo, was never in V05: the feature fetches a restored line back through
the store). Removing a line clears its gift wrap (R3.4) in `Undo`'s capture. The portal wires the
feature's `restored` to an "Item restored" notice, as the cart does. The cart's checkout button is a
`checkout_button` component patched from the summary like the other priced parts, so a Turbo change
updates its total and disables it when the cart empties. And a waiting checkout page no longer
depends on catching the payment broadcast: a Stimulus `catch_up` controller on the processing step
asks `GET /cart/checkout/status` when it appears and whenever its stream subscribes, and the kept
composition answers with the outcome (`Checkout::OUTCOMES`) or 204 while it is still processing.

*Across processes:* each process (Puma worker, Solid Queue worker) keeps its own compositions; they
agree through the database alone. Every write a kept composition reads bumps the cart's `version`,
and `LongLived#with` sends `reload` when it moved, so a request is consistent once that check has
run. A payment job in its own process exposed a gap (fixed 2026-10-19, two tests): the checkout's
`reload` skipped its flow's kept `Checkout` record, so the web process kept answering "processing".
Product writes were a second gap (fixed 2026-10-19, four tests): they moved no cart's stamp, so a kept
cart showed a changed price and a kept checkout charged it. A product's commit now bumps every open
cart that shows it (`Cart.holding`: its lines, saved items and wishlist), and settlement takes stock
through the record so its commit does the same. A third (fixed 2026-10-19, two tests): `with`
recorded the stamp read after the request as seen, so another writer's bump committed during the
request was never reloaded. It now keeps the reading taken before; the cost is a `reload` on the
request after one that wrote. `DESIGN.md`, "Other writers", has the rest.

*Later (2026-10-21): outside change is a paradigm.* `ProgrammingParadigms::ChangeFeed` replaces
`LiveUpdate`, which broadcast rendered rows and badges to every page on the stream. A change is now
published as a fact keyed by identity (`{ product_id: }`, `{ product_id:, stock: }`, a cart's
payment `outcome`) by a `ChangeFeed::Publish` sink the changing screen wires; each page places a
`ChangeFeed::Subscription` configured with its topic and kinds, and its screen wires the feed's kinds to the parts
that care (`feed.stock → order.product` on the cart). The browser half (`change_feed_controller.js`) posts a
fact the page listens to back to the page's own `live` URL, and the page's composition answers:
patches on the cart, the outcome on the checkout, the lists drawn again on the catalogue and the
portal. One gap closed by a wire: a staff edit at /products never reached an open cart or portal.
`DESIGN.md`, "Outside change as a paradigm", has the rest.

## Run it

```bash
cd v05-shared-feature         # asdf picks Ruby 4.0.7 from .ruby-version
bin/rails db:prepare db:seed  # Postgres at localhost, user postgres/postgres (see config/database.yml)
bin/dev                       # http://localhost:3000
bin/rails test
```

## What's where

| Layer | Directory | Holds |
|---|---|---|
| Application | `app/ala/screens/`, `app/controllers/`, `app/views/{products,carts,checkouts,portals,...}`, `config/routes.rb` | `Screens::Store` (the calibration: rates, codes, tiers, words); one screen per page that builds, configures and wires instances (the cart's once per cart and kept, the others per request); controllers that push one input and redirect or render; page templates that place components |
| Features | `app/ala/features/` | `OrderLines`: a composition of `CartLines` and `Undo` with ports, placed by the cart page and the portal page |
| Domain abstractions | `app/ala/domain_abstractions/`, `app/views/components/` | `CartLines`, `SavedItems`, `Wishlist` (values), `CartItemsStore`, `SavedItemsStore`, `WishlistStore` (their stores), `Undo`, `ProductIndex`, `PricingChoices`, `CartTotals`, `OrderTotals`, `CheckoutFlow`, `SubmitOrder`, `Records`, `AddLine`, `Charge`, `SettleOrder`; the domain UI partials that take projected rows and words: `cart_line`, `saved_line`, `wishlist_line`, `order_line`, `catalog_order_row`, `product_row`, `cart_summary`, `shipping_selector`, `promo_form`, `checkout_button`, `checkout_status` |
| Rules | `app/ala/rules/`, `app/views/elements/` | the pure rules and projections (`Pricing`, `CalculateShipping`, `CalculateGiftWrapCost`, `ValidatePromo`, `VolumeTier`, `StockStatus`, `CheckStock`, `BuildLineItems`, `ProductRow`, `LineRow`); the generic UI elements (`product_line`, `stock_badge`, `record_form`, `modal`, `tabs`, `milestones`, `notice_with_action`, `flash`, `none`) |
| Programming paradigms | `app/ala/programming_paradigms/` | `DataFlow`, `Event`, `RequestResponse` (each builds its port objects), `Transitions` (the state-machine table), `PersistedSteps` (a state machine whose state is a record's `step` column), `ChangeFeed` (outside change: a `Publish` sink, a `Subscription` part a page places, the fact format they share), `Patches` and `Patch` (a Turbo Stream response built from outputs), `PushLater` (an Active Job that rebuilds a screen and pushes an input), `LongLived` (one kept composition per key, one thread at a time, reloaded when the store's stamp moved; registries by name), `Drawing` (the built graph as Mermaid, structural or as it ran) |
| Foundation | `app/ala/foundation/`, `app/models/`, `app/javascript/controllers/` | `Ports` (ports, wiring and `forward`), `Trace` (hops recorded while a test run is on), `Money`, `DomTargets` (the DOM names live updates target, declared as a view helper), `LedgerGateway`; the Active Record models as persistence, one per feature; eight small Stimulus controllers (`change-feed` is the paradigm's browser half) |

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
if the cart's `version` moved since its last request started, with its flash and patches
cleared; then answers with the patches the outputs made. `Screens::Cart.new` builds the page's
instances, configures them from `Screens::Store`, and wires them: `@lines.wire_to(@undo, from: :removed, to: :capture)`, `@undo.on(:restored) { say
:notice, "Item restored" }`. Data moves between instances through their ports; the screen keeps only
what lands (`@totals.on(:summary) { @summary = _1 }`), and the view reads it. See `DESIGN.md`.
