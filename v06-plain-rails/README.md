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

**Status:** 57 integration tests (V03's, plus one the trace asked for) and 5 Cuprite browser tests,
0 failures; after the full suite, **0 declared outputs never routed**; RuboCop clean;
`../../ala_lint_ruby/bin/ala_lint --root . --super-strict` scores it **100/100 at every tier with
no scored finding and no accepted line** (324 functions). The linter learned two shapes to read it,
recorded in `LINT_NOTES.md`. Familiarity 5 of 5 (judgement): a plain class, methods that return a
Hash, and one `case`.

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
| Application | `app/ala/screens/`, `app/controllers/`, `app/views/{products,carts,checkouts,portals,...}`, `config/routes.rb` | `Screens::Store` (the calibration); one screen per page that builds and configures its parts and wires them in `wire`; controllers that call one input and redirect or render; page templates that place components |
| Domain abstractions | `app/ala/domain_abstractions/`, `app/views/components/` | `CartLines`, `SavedItems`, `Wishlist` (values), `CartItemsStore`, `SavedItemsStore`, `WishlistStore` (their stores), `Undo`, `ProductIndex`, `PricingChoices`, `CartTotals`, `OrderTotals`, `CheckoutFlow`, `SubmitOrder`, `Records`, `AddLine`, `Charge`, `SettleOrder`; the domain UI partials |
| Rules | `app/ala/rules/`, `app/views/elements/` | the pure rules and projections; the generic UI elements |
| Programming paradigms | `app/ala/programming_paradigms/` | `Wiring` (`run`, and the trace hooks), `Transitions`, `LiveUpdate` (a Turbo Stream broadcast sink), `Patches` (a Turbo Stream response), `PushLater` (an Active Job that rebuilds a screen and calls an input), `Drawing` (the wire arms as Mermaid, structural or as they ran) |
| Foundation | `app/ala/foundation/`, `app/models/`, `app/javascript/controllers/` | `Trace`, `Money`, `DomTargets`, `LedgerGateway`; the Active Record models as persistence; five small Stimulus controllers |

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
