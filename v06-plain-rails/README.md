# V06: Plain Rails

V03 (`../v03-pure-core-streams`) written in the Ruby a Rails developer already reads, the way V50
did for Phoenix: **no port macros, no port objects, no `emit` or `ask`.** A domain abstraction is a
plain class; an input is a public method; its outputs are the pairs the method returns. A screen is a
plain class whose wiring is one `wire(part, output, payload)` method, a `case` over `[part, output]`
with an arm per wire, and a three-line `run` that feeds what a part returned through it. A pull is an
argument: `@lines.load(@items.lookup)`. The values, the stores, the Turbo Stream patches, the
per-request screens and the layer map are V03's; what changed is how a port is spelled, which is
to say the whole Foundation, from ninety lines to none. `DESIGN.md` has the shape and the hand walk.

Because every output passes through `run`, the trace that V05 added to the Foundation comes free
here: `Foundation::Trace` is thirteen lines, the test suite turns it on, after a full run every
declared output must have been routed at least once, and `docs/diagrams/running/` draws each screen
from the hops. The structural drawing in `docs/diagrams/` is read from the `wire` arms with Prism.

**Status:** 85 integration and unit tests (V03's, plus one the trace asked for, 18 unit tests of the
abstractions extracted 2026-10-19, one for `CartLines#find`'s refusal, fixed that day, 3 for the
defect fixes below, and 6 for the live paradigm of 2026-10-21) and 11 Cuprite browser tests, 0 failures; after the full suite, **0 declared outputs never routed**; RuboCop clean;
`../../ala_lint_ruby/bin/ala_lint --root . --super-strict` scores it **100/100 at every tier with
no scored finding**, 10 of 10 rules met (353 functions; one inherent declaration, the drawing's edge
label, added 2026-10-19 when the linter's Prism fix first checked `drawing.rb` and `wiring.rb`; two
accepted lines, below). The linter learned two shapes to read it,
recorded in `LINT_NOTES.md`. Familiarity 5 of 5 (judgement): a plain class, methods that return a
Hash, and one `case`.

*Since 2026-10-19:* the linter's clone check (duplicated logic, R7, scored from `--strict`) found 8
duplicates, which held both strict tiers to 98. Seven were one concept written twice and are now one
abstraction each: `Rules::LineRequest` (a product id or `{ product_id:, quantity: }`, read by `AddLine`
and `CartLines#receive`); `Rules::LineRow` (a held line shown as its product, each product looked up
once, in place of three row projections and three product caches; each screen configures one per
value with that value's links); `Rules::Pricing.summary` (the figures both totals show); and
`ProgrammingParadigms::Wizard` (a multi-step form kept in a record, the shared core of
`CheckoutFlow` and `SubmitOrder`, which their screens configure with the flow table). Two lines are
accepted: `CartLines#save_for_later` mirrors `SavedItems#move_to_cart` (each list removes its own
line and hands on the same `{ product_id:, quantity: }`), and `CheckoutFlow#show` is its wizard's
`visit` unchanged, delegation in place of inheritance (§7.16). `ala_lint --list-accepted` shows both.
The two `clone_inside` reports (unscored) are left as they were.

*Fixes ported from V07 (2026-10-19), each test first:* an undo over Turbo now puts the line back
through the lines value (`[ :undo, :restored ]` pulls it from the store and hands it to
`CartLines#arrived`), so the row reappears and the totals follow; removing a line clears its gift
wrap (R3.4, in `Undo#capture`); the portal's undo flashes "Item restored" instead of grounding it;
the checkout button is a component the summary arm patches, so its total and its disabled state
follow every change; and the payment's waiting step asks `GET /cart/checkout/status` (a Stimulus
`catch-up` controller) when it appears and whenever its stream subscribes, so an outcome broadcast
before the page was listening is not lost.

*Later (2026-10-21): outside change is one paradigm.* `ProgrammingParadigms::ChangeFeed` replaces
`LiveUpdate` and the hand-built paths around it: the catalogue's three rendered-row broadcasts, the
checkout's stock-badge broadcast and its payment-status broadcast, and the payment page's
`catch-up` controller with the `GET /cart/checkout/status` it asked. A screen that makes a change
wires it to a `ChangeFeed::Publish` sink (`settle.stock_changed → stock_news`, `records.updated →
product_news`, `charge.charged → payment_news`); a page renders the `ChangeFeed::Subscription` its screen configures
with what it listens to (the cart: `stock` and `product`; the checkout's waiting step: its own
`payment`, asking again on each subscription). What travels is a fact, a kind and identity keys
(`{ kind: "stock", product_id:, stock: }`), never HTML. A fact the page hears refreshes it (a Turbo
morph), and the rebuilt screen reads the current values through the tables it is configured with;
the refresh keeps an open modal, the flash, typed input and the cart's tab. The topics are named once,
in `Screens::Topics`. Moving onto it closed three gaps the old broadcasts had, each shown failing on the
old code first: a staff stock edit at /products never reached an open cart; a product created at
/products never reached an open portal; and a staff edit of a product replaced the portal's
catalogue row with the /products row (Edit and Delete in place of the quantity field). The checkout
and portal templates now pick a step's partial from a literal `STEP_VIEWS` table instead of a name
built from the step.

## Run it

```bash
cd v06-plain-rails            # asdf picks Ruby 4.0.7 from .ruby-version
bin/rails db:prepare db:seed  # Postgres at localhost, user postgres/postgres (see config/database.yml)
bin/dev                       # http://localhost:3000
bin/rails test                # fails if a declared output never routed
bin/rails ala:diagrams        # docs/diagrams/*.md from the wire arms
```

## What's where

| Layer | Directory | Holds |
|---|---|---|
| Application | `app/ala/screens/`, `app/controllers/`, `app/views/{products,carts,checkouts,portals,...}`, `config/routes.rb` | `Screens::Store` (the calibration), `Screens::Topics` (the live topics); one screen per page that builds and configures its parts and wires them in `wire`; controllers that call one input and redirect or render; page templates that place components |
| Domain abstractions | `app/ala/domain_abstractions/`, `app/views/components/` | `CartLines`, `SavedItems`, `Wishlist` (values), `CartItemsStore`, `SavedItemsStore`, `WishlistStore` (their stores), `Undo`, `ProductIndex`, `PricingChoices`, `CartTotals`, `OrderTotals`, `CheckoutFlow`, `SubmitOrder`, `Records`, `AddLine`, `Charge`, `SettleOrder`; the domain UI partials |
| Rules | `app/ala/rules/`, `app/views/elements/` | the pure rules and projections (among them `LineRow`, a held line shown as its product); the generic UI elements |
| Programming paradigms | `app/ala/programming_paradigms/` | `Wiring` (`run`, and the trace hooks), `Transitions`, `Wizard` (a step flow kept in a record), `ChangeFeed` (outside change: a `Publish` sink, a `Subscription` a page renders, and the channel between them), `Patches` (a Turbo Stream response), `PushLater` (an Active Job that rebuilds a screen and calls an input), `Drawing` (the wire arms as Mermaid, structural or as they ran) |
| Foundation | `app/ala/foundation/`, `app/models/`, `app/javascript/controllers/` | `Trace`, `Money`, `DomTargets`, `LedgerGateway`; the Active Record models as persistence; six small Stimulus controllers (`change-feed` is the page's end of `ChangeFeed`) |

## How a request runs

```ruby
class CartItemsController < ApplicationController
  def destroy
    screen.remove(params[:id].to_i)   # one input
    back_to_cart                       # the patches the arms made, or a redirect
  end
end

class Screens::Cart
  include ProgrammingParadigms::Wiring

  def remove(item_id) = (load; run(:lines, @lines.remove(item_id)))

  private

  def wire(part, output, payload)
    case [ part, output ]
    in [ :lines, :changed ] then run(:items, @items.apply(payload))
    in [ :lines, :removed ] then run(:undo, @undo.capture(payload))
    in [ :lines, :row_removed ] then @patches.remove(@dom.cart_line_id(payload[:id]))
    in [ :lines, :contents ] then run(:totals, @totals.contents(payload))
    in [ :totals, :summary ] then @summary = payload; ...
    end
  end
end
```

`CartLines#remove` returns `{ removed: id, row_removed: row, contents: {...} }`; `run` sends each pair
to `wire`; an arm either runs another part with it or keeps it for the page. See `DESIGN.md`.
