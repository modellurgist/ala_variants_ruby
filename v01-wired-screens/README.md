# V01: Wired Screens (Rails)

The storefront and B2B portal from `ala_lab/docs/requirements-storefront-and-portal.md`, built as a
Rails 8.1 app that follows the Ruby and Rails edition of the ALA Checklist
(`ala_checklist/ala_checklist_ruby.md`). Where a conventional Rails choice met the checklist it was
taken; where it didn't, the nearest choice that still reads as Rails was.

**Status:** 48 tests, 0 failures (41 integration tests ported from the Elixir variants' acceptance
suites, plus wiring-coverage and domain unit tests). The browser paths the integration tests can't
reach (modal form with live validation, tabs, the undo countdown, the auto-submitting shipping
choice, and the payment job's live redirect) were exercised by hand in Chrome against the dev server.
`../../ala_lint_ruby/bin/ala_lint --root .` scores it 65/100 at the default tier (24 scored findings over 200
functions, 94% of functions clean); `LINT_NOTES.md` reads each finding and lists the changes to
decide on. The hand walk of the checklist is in `DESIGN.md`.

## Run it

```bash
cd v01-wired-screens          # asdf picks Ruby 4.0.7 from .ruby-version
bin/rails db:prepare db:seed  # Postgres at localhost, user postgres/postgres (see config/database.yml)
bin/dev                       # http://localhost:3000
bin/rails test
```

## What's where

| Layer | Directory | Holds |
|---|---|---|
| Application | `app/ala/screens/`, `app/controllers/`, `app/views/{products,carts,checkouts,portals,...}`, `config/routes.rb` | `Screens::Store` (the calibration: rates, codes, tiers, words); one screen per page that builds, configures and wires instances per request; controllers that push one input and redirect or render; page templates that place components |
| Domain abstractions | `app/ala/domain_abstractions/` | `CartLines`, `Undo`, `SavedItems`, `Wishlist`, `PricingChoices`, `CartTotals`, `OrderTotals`, `CheckoutFlow`, `SubmitOrder`, `Records`, `AddLine`, `Charge`, `SettleOrder`, and the pure rules (`Pricing`, `CalculateShipping`, `ValidatePromo`, `VolumeTier`, `StockStatus`, `CheckStock`, `BuildLineItems`, `ProductRow`) |
| Domain UI abstractions | `app/views/components/` | partials that take projected rows, words and URLs: `product_line`, `cart_line`, `order_line`, `catalog_order_row`, `stock_badge`, `cart_summary`, `shipping_selector`, `promo_form`, `record_form`, `modal`, `tabs`, `milestones`, `notice_with_action`, `checkout_status`, `flash`, `none` |
| Programming paradigms | `app/ala/programming_paradigms/` | `DataFlow`, `Event`, `RequestResponse` (each builds its port objects), `Transitions` (the state-machine table) |
| Foundation | `app/ala/foundation/`, `app/models/`, `app/helpers/live_targets_helper.rb`, `app/javascript/controllers/` | `Ports` (ports and wiring), `Money`, `PushLater` (an Active Job that rebuilds a screen and pushes an input), `LiveUpdate` (a Turbo Stream broadcast sink), `LedgerGateway`; the Active Record models as persistence, one per feature; the DOM names live updates target; five small Stimulus controllers |

Each feature keeps its own table against the cart's identity (R10): `cart_items` (the lines both
the storefront and the portal build on), `saved_items`, `wishlist_items`, `cart_pricing_choices`,
`checkouts`, `order_submissions`, `orders`.

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
