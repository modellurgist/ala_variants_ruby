# V02 design: wired rows

V01 with the changes its lint and its hand walk asked for (`../v01-wired-screens/LINT_NOTES.md`).
The shape is the same: one per-request screen composition per page, domain abstractions wired port
to port, Rails doing what it usually does around them. What changes is where the knowledge sits, so
that every edge drops, no two features read one record, and pages hold no logic. The target is a
clean run of `ala_lint_ruby` at `--super-strict` and a clean hand walk of the Ruby checklist.

## The layer map (declared in `.ala_lint.rb`)

| layer | holds | why it's its own layer |
|---|---|---|
| **application** | `Screens::*`, controllers, page templates, routes | the composition: instances, configuration, wiring, words |
| **domain** | `DomainAbstractions::*` (stateful, ported), `views/components/` (domain UI: a cart line, an order line, a catalogue row, a price summary) | abstractions that know a concept of the store's world |
| **rules** | `Rules::*` (pure: pricing, shipping, promo, volume tier, stock status, line items, the product projection), `views/elements/` (generic UI: a product line, a stock badge, tabs, a modal, milestones, a record form) | significantly more general than the domain: they take any input and know no store |
| **paradigms** | `DataFlow`, `Event`, `RequestResponse`, `Transitions`, `LiveUpdate` (a broadcast sink), `PushLater` (an asynchronous execution model) | how a connection runs |
| **foundation** | `Ports`, `Money`, `DomTargets`, `LedgerGateway`, the Active Record models | the wiring operator, the money type, the names, the stores |

V01 had one domain layer and found seven peer edges in it (totals → pricing, flow → stock check) and
eight more in its components (a cart line rendering a product line and a stock badge). Each was a
genuine drop the map didn't declare. Spray names his own layers per project (§2.3.1); this map says
what V01's prose already assumed.

## What changes, and the finding it answers

**Rules under the domain (R1).** `CartTotals`, `OrderTotals` and `CheckoutFlow` call `Rules::Pricing`
and `Rules::CheckStock`: a drop. The screens configure `Rules::StockStatus`, `Rules::ProductRow`,
`Rules::CalculateShipping` and the rest as before.

**Elements under components (R1).** A component (`cart_line`) renders elements (`product_line`,
`stock_badge`); no component renders a component, no element renders an element with store
knowledge. Pages place components; the four pages that showed a list in V01 render a collection.

**Product data through a pull port (R10).** The line tables (`cart_items`, `saved_items`,
`wishlist_items`) lose `belongs_to :product` and `includes(:product)`. `CartLines`, `SavedItems`
and `Wishlist` get an output `products` (request/response): they ask for the projected rows of the
product ids they hold, and the screen wires all three to one `ProductIndex` instance configured
with the catalogue's model and the `Rules::ProductRow` projection. The features share the product
id (the identity key) and nothing else; the catalogue's shape can change without editing the cart.

**Rows carry what the page needs (R11).** Each row a feature emits carries its own URLs, from a
`links` lambda the screen configures with the route helpers (`->(id) { { remove:
urls.cart_item_path(id), ... } }`): a small function passed in as configuration (§3.11.3), so no
component knows a route and no page computes one per row. The cart line takes the wishlist's ids
and marks itself; the tabs element takes counts and words and writes its labels.

**Names flow down (R5).** `Foundation::DomTargets` (the DOM ids and marker classes live updates
target) is declared with `helper` so elements render them and screens broadcast to them, both
depending down. The checkout's status target and the modal's frame name are screen constants the
pages pass to the components as locals.

**Execution models in the paradigms layer (R1).** `LiveUpdate` and `PushLater` use `DataFlow`, so
they sit beside it. Rendering a component outside a request is the application's business:
`Screens::Component.render` wraps `ApplicationController.render`, and the screens' render lambdas
call it.

**Outcomes as outputs (R11).** `Records` emits `created` and `updated` instead of `saved`, so the
screen wires each to its own notice and live update (append for a new row, replace for an edited
one) with no branch; `show` emits `record`, apart from `form`. `SubmitOrder` emits its step after a
failed submit, as `CheckoutFlow` already did, so the controller's failure arm only renders. The
form's URL comes from `form_with model:`, Rails' own convention, instead of a `persisted?` ternary
in the page; the modal's title comes from the page that opened it. `Undo.expired` and
`SettleOrder.settled`, wired by nobody, are gone.

**Session fallback (R11).** `current_cart_id` reads `session.fetch(:cart_id) { cart_id }`: the
guard moved into the connection mechanism (the session's own default). It decides nothing the
application should see.

## Still true from V01

Per-request compositions; stores configured in; broadcasts wired from screens, never from model
callbacks; the payment as a `PushLater` job that rebuilds the screen; undo as `removed_at` plus a
browser countdown with a server-side purge; the calibration in `Screens::Store`. Puma's threads
never share an instance.

## Where the shape costs something

- Three more directories (`rules/`, `views/elements/`, and `ProductIndex`) for a store this size.
- Every list is a `render collection:`; a page that wants one row different has to say so in the
  row's data, not in the template.
- `ProductIndex` is one more query per page where V01 joined; the join was the coupling.
- The session fallback and the controllers' routing branches remain the framework's forms.

## Checklist walk (Ruby edition, by hand)

After the build: 48 tests green, RuboCop clean, `ala_lint` 100/100 at every tier with no scored
finding (`LINT_NOTES.md`). The walk below is what the linter can't decide.

| Rule | Verdict | Evidence |
|---|---|---|
| R1 edges drop | met | every reference, `new`, superclass, mixin, render and helper call drops through the declared map; the two calls the map allows as peers are execution models building the ports they run |
| R2 no shared mutable state | met, one note | values on wires are hashes built per call, `Money` is frozen; `Records`, `CheckoutFlow` and `SubmitOrder` emit a live Active Record object on `form`/`record`/`created`, which only the composition lands for the view to render; nothing below the composition holds one |
| R3 literals at the composition | met | `Screens::Store` and each screen's `TEXTS`/`FLOW`/`MILESTONES`; the one default below (`links: ->(_id) { {} }`) is the simplest form, not a product decision |
| R4 state with its owner | met | every stateful instance owns a store; screens land values in wiring blocks and controllers hand the page constants, parameters and landed values |
| R5 no silent contracts | met | DOM names through `DomTargets`; the status target and modal frame are screen constants the pages pass down; routes reach components only as URLs on rows |
| R6 nameable | met | each class and partial header names its concept, ports and configuration; `ProductIndex`, `Partial` and `DomTargets` each know one thing |
| R7 earns its existence | judgement | `saved_line` and `wishlist_line` are five-line components that exist so the page can render a collection; `ProductIndex` is one port; the alternative (a join) was the R10 coupling |
| R8 reads as requirements | judgement | a screen's constructor reads as the page's wiring; the coverage test lists every port left open and the list shrank to ports a screen has no use for |
| R9 ports by paradigm | met | all ports are `DataFlow`, `Event` or `RequestResponse`; outputs are named as facts (`removed`, `created`, `taken`, `stock_changed`); the gateway and stores are configuration; no public method beyond constructors, configuration and `parts` |
| R10 no shared entity | met | per-feature tables; `cart_items` is shared by the storefront and the portal as the lines abstraction both build on (V01's one noted share, unchanged); product data only through the `products` port |
| R11 composition only | met, with the framework's forms | no logic in screens; controllers route outcomes to responses; pages place components and collections; `session.fetch` holds the one fallback |
