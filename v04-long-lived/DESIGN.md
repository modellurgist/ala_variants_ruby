# V04 design: a composition that lives across requests

V03 with the one thing a Rails ALA app had not yet done: the cart page's composition is built once
per cart and kept. V03's pure core and patches are what make it possible (a value that holds the
cart in memory, and a response that is only what changed); they are kept as they were and described
below under their V03 headings. This document records V04's change first, then V03's, and the hand
walk after the build.

## The composition lives across requests (new in V04)

Spray's program is wired once and then runs (§3.11.3). A Rails request has no "then": V01 to V03
built the screen, pushed one input, rendered, and threw it away, so every change loaded every value
before it could apply one input. V04 keeps the cart's screen:

```ruby
# config/initializers/compositions.rb
Rails.configuration.x.cart_screens = ProgrammingParadigms::LongLived.new(
  build: ->(cart_id) { Screens::Cart.new(cart_id:) },
  version: ->(cart_id) { Cart.version_of(cart_id) },
  reload: :reload, begin: :begin, capacity: 1000)

# app/controllers/concerns/cart_screen.rb
def change
  with_screen do |screen|          # the cart's composition, one request at a time
    yield screen                   # one input
    respond_to ... screen.patches  # what its outputs made
  end
end
```

`LongLived` is an execution model in the paradigms layer, beside `PushLater` and `LiveUpdate`: it
knows threads and staleness and nothing about carts. Three decisions it makes, and where Spray puts
each:

- **Threads.** Puma serves requests on several threads, and a value is not thread-safe (§3.9 wants
  it that way: an instance is used by one thread, decided outside it). The registry holds one lock
  per kept composition and runs a request under it; two requests on one cart take turns, two carts
  run at once. Spray's arbitrator (§3.10.2) is this object, at wiring time, never a `Mutex` in a
  domain class (the linter's R4 check, accepted on the two lines where the locks are made).
- **Other writers.** A second Puma process, the checkout job, the catalogue's "add to cart" and the
  portal all write the same tables without going through this composition. `carts.version` is the
  cart's write stamp: every row that belongs to a cart bumps it on commit (`after_commit { Cart.bump
  (cart_id) }` in the four line models, accepted under R1 as the store's own stamp, not a decision).
  The registry reads the stamp before each request and sends `reload` when it moved, then records
  the stamp after the request so the composition's own writes are not stale. A composition kept by
  another process sees the bump on its next request: no cache invalidation bus, one integer column.
- **A request's own state.** Flash and patches belong to one request; `begin` clears them. Values,
  landed rows and the summary belong to the cart and stay.

What the screen changed:

- `reload` is V03's `load` (every value pulled from its store); `show` asks the values to say what they
  hold (`rows`, `contents`, counts, ids again, from memory) for a GET; each change input is now one
  push, with no load in front.
- Three values gained a `show` input. `CartItemsStore` gained `fetch` → `found`, so a line that
  `Undo` restores comes back into `CartLines` through the store the way an added line does
  (`@undo.wire_to(@items, from: :restored, to: :fetch)`, `@items.wire_to(@lines, from: :found, to:
  :arrived)`). V03 never needed it: the next request reloaded.
- The controllers render inside the composition's turn, so a page or a patch set is what this
  request made and nothing another thread did meanwhile.

Checkout and the portal stay per request. The checkout runs in a job as well as in requests, and
the portal's lines are its flow's input; neither has V03's patches to make a kept composition pay.
That asymmetry is a finding, not a plan: the cart is the page with the most state and the most
clicks, and it is where keeping the composition shows.

### What it costs

- One process-wide table of compositions with a capacity (the oldest cart is dropped and rebuilt on
  its next request), one lock per cart, and `to_prepare` so development reloads rebuild the table.
- A GET on a kept cart runs no store queries except `Undo`'s window check and the version read; a
  change runs the one write its input decided plus the stamp. V03 ran every load on every request.
- Memory per kept cart: the values, their catalogue snapshots and the landed rows. A thousand carts of
  a few lines is small; a long tail of abandoned carts is what `capacity` bounds.
- Correctness now rests on the stamp. A write that bypasses the models (`update_all`, SQL) is invisible
  until something bumps the cart; the test "a write by another process" shows both halves.
- Multi-process deployments keep one composition per cart per process, each reloading on the other's
  bump. That is correct and wasteful in proportion to the process count; sticky sessions would make it
  one, and are outside the design.

## The state abstractions are values (from V50/V51, V03)

V02's `CartLines`, `SavedItems` and `Wishlist` owned a model and did their own I/O, which is Spray's
own form but meant nothing below the composition ran without Postgres. V03 makes them values with
the shape V50's features have: pulled through a port on load, changed in memory, every change sent
out for a store the composition wires.

```ruby
@lines.wire_to(@items, from: :items, to: :lookup)      # the lines, pulled (RequestResponse)
@lines.wire_to(@items, from: :changed, to: :apply)     # every change, written ({ op:, ... })
@lines.wire_to(@items, from: :adding, to: :add)        # a new line asked for ...
@items.wire_to(@lines, from: :added, to: :arrived)     # ... and handed back with its id
```

`CartItemsStore`, `SavedItemsStore` and `WishlistStore` are the data source-and-sink abstractions
(§5.2.2) with `lookup`, `apply` and (for lines) `add`. A value's tests wire fakes to its ports and
run with no database (`test/ala/pure_core_test.rb`). Because a screen is built per request, every
input that changes a value loads it first: V51's "load → apply → write" within one request.

What stayed store-backed, and why: `Undo` (its held removal must outlive the request, and
`removed_at` is where it lives), `PricingChoices` (two columns, read and written in place),
`Records`, `CheckoutFlow`, `SubmitOrder`, `SettleOrder`, `AddLine` (flows and placements that own a
table by design). The pure core is the three lists a shopper edits, which are the three that change
on every click.

## A change answers with patches (from V50's streams, V03)

V02 redirected after every change and let Turbo morph the page: a full render per click, hidden.
V03's values emit **deltas** (`row_added`, `row_changed`, `row_removed`, and `rows_changed` for a
pane) beside the full `rows` a GET renders, and the screen wires each delta, the summary, the undo
offer, the tab counts and the selectors to a `Patch` sink:

```ruby
@lines.wire_to(patch(:replace, ->(row) { dom.cart_line_id(row[:id]) }, line_html), from: :row_changed)
@totals.wire_to(patch(:update, dom.summary_id, ->(summary) { Partial.render("components/cart_summary", summary:, t: t[:cart]) }), from: :summary)
```

`ProgrammingParadigms::Patches` is the response: a buffer the sinks add to, where the last patch of a
target wins (a summary re-emitted by every load and change is sent once), rendered through the
controller's `turbo_stream` builder. The controller concern answers a Turbo request with the patches
and a plain request with the old redirect, so V02's integration tests pass unchanged and four new
ones assert the stream. The page's targets are `Foundation::DomTargets` names, which the page renders
and the screen patches: the same agreed-names module, more names.

Two things this forced out of the domain: `Undo` now announces `pending` after every change, not only
on load, and `PricingChoices` announces a shipping or promo choice as it is made. V02 could rely on the
reload to show those; a page that is patched can't.

## What V03 cost

- A change request loads every part before applying one input (as a GET does) and then answers with
  only what changed. The queries are V02's; the render is a few partials instead of a page.
- The cart screen is 140 lines, up from 90: the wiring now says where each output lands on the page
  as well as which instance it reaches. That is the "display inside" wiring Spray draws, written as
  sinks.
- Eleven DOM ids in `DomTargets`, up from three.
- A value's internal fields can't share a name with its ports (`@held`, `@catalog`, `@wanted`), a
  constraint of the ninety-line Foundation that bit three times.

## The layer map (declared in `.ala_lint.rb`, unchanged from V02)

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

## V02's changes, kept

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

After the build: 66 + 5 tests green, RuboCop clean, `ala_lint` 100/100 at every tier with six
accepted lines. V02's and V03's walks hold; what V04 adds or changes:

| Rule | Verdict | Evidence |
|---|---|---|
| R4 | met | the values hold the cart between requests, and the one thing deciding who may use them when is the execution model that keeps them (§3.9, §3.10.2); no class holds a lock or checks a thread |
| R1 | met, with a stamp | a line model's commit bumps its cart's version: the foundation knowing its own tables, not the composition; accepted and listed |
| R9 | met | `LongLived` has a four-word interface (`with`, `size`, `held?`, `clear`) and is configured with lambdas and input names, so a second long-lived screen is one more registry |
| R11 | met | the screen's change inputs are one push each; the controllers' `change` block is one input; rendering stays in the view |
| R3 | met | the table's capacity is configured in the initializer, not defaulted in the class (the linter asked) |

What V03 added:

| Rule | Verdict | Evidence |
|---|---|---|
| R2 | met, better | the lines, saved items and wishlist no longer hand a live record to anyone: values on wires are hashes built per call, and the store sees only `{ op:, ... }` |
| R4 | met | state in the value that owns it for the request; the store is a wired sink, not a field the composition reads |
| R9 | met | three new source/sink abstractions with `lookup`/`apply`/`add` ports; `Patch` and `Patches` are a paradigm's sink and buffer; a pane's item partial is passed in by the page (a UI-layout port), not named by the pane |
| R10 | met | unchanged: product data through `ProductIndex`; the stores see ids |
| R11 | met | the screen's inputs call `load` then one push, each a line of wiring; the patch lambdas render partials with landed values and compute nothing |
| R7 | judgement | three stores of 20 lines each, and `Patches` at 15: the price of a store-free core |
| R8 | judgement | a screen that says where every output lands reads longer and more like the page than V02's; the coverage test lists every port left open |
