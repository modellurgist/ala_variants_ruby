# V05 design: a feature two pages place, and the wiring as it ran

V04 with Spray's Features layer and one feature in it, used by two pages; then, a day later, three
more things built into the same variant rather than a V06: port forwarding, a running trace with a
coverage check, and the checkout kept across requests with the job delivering into it. V04's
long-lived cart and V03's pure core and patches are kept as they were and described below under
their own headings. This document records the latest changes first, then V05's, V04's and V03's,
and the hand walk after the build.

## Outside change as a paradigm (Later, 2026-10-21)

Until now a change made elsewhere reached open pages through `LiveUpdate`: the screen that made the
change rendered a product row or a stock badge and broadcast it to every page on the `catalog`
stream, which each page targeted by DOM id or class. The publisher knew every view (R1, R10), and it
missed what no broadcast targeted. The live paths it carried:

| change | published by | reached |
|---|---|---|
| product created, updated, deleted at /products (R2.5) | `Catalog`: `records.created/updated/deleted` | product list (append, replace, remove a row), product page, and, by its row id, the portal's catalogue row, replaced with the *staff* row and its edit and delete buttons (a defect) |
| stock taken by a paid order (R2.6, R3.14, R6.8) | `Checkout`: `settle.stock_changed` | every `.stock_<id>` badge: product list, product page, cart lines, portal lines and catalogue |
| payment outcome | `Checkout`: `charge.charged/declined` | the cart's own checkout page, its status box, on `checkout_<cart_id>` |

A staff stock or price edit reached product lists only: an open cart or portal kept its badge and
prices until a reload. A portal submission takes no stock in this variant, so it publishes nothing.

`ProgrammingParadigms::ChangeFeed` (`app/ala/programming_paradigms/change_feed.rb`) is the paradigm, in the layer
Spray puts paradigm interfaces (§2.2), with the observer inside it (§4.4.2):

```ruby
# publish side: the composition making the change wires it to a sink with a topic and a kind
changed = ChangeFeed::Publish.new(topic: Store::CATALOG_TOPIC, kind: :product, fact: ->(p) { { product_id: p.id } })
@records.wire_to(changed, from: :updated)
@settle.wire_to(ChangeFeed::Publish.new(topic: Store::CATALOG_TOPIC, kind: :stock, fact: ->(level) { level }), from: :stock_changed)

# subscribe side: the page places a feed with what it listens to and wires the kinds to the parts that care
@feed = ChangeFeed::Subscription.new(topic: Store::CATALOG_TOPIC, kinds: %i[stock product])
@feed.wire_to(@order, from: :stock, to: :product)
@feed.wire_to(@order, from: :product, to: :product)
@feed.wire_to(@saved, from: :product, to: :product)
```

- **What travels** is a fact: a kind and identity-keyed values, as a `<turbo-stream action="change_feed">`
  carrying JSON and no markup. `ChangeFeed.message` writes it and `ChangeFeed.read` reads it back, so publisher and
  subscriber are two ends of one format and share only the product id (or the cart id).
- **Delivery.** A Rails page is not a process, so the paradigm's browser half (`change_feed_controller.js`,
  placed by the `change_feed` helper with the page's topic stream) posts a fact of a kind the page
  listens to back to the page's own `live` URL. The controller pushes it into the screen's `live`
  input, the feed hands it to the wired parts, and the page answers with what changed: the cart its
  patches (a line asked for its product again, the summary, the saved and wishlist panes), the checkout
  its outcome (`feed.outcome` shows the flow's step), the product list and the portal their lists
  drawn again from the tables (`feed.stock` → `records.load`, `order.load`, `catalog.load`), morphed in.
  The product page shows its one product again. Kept compositions are already current: the change's
  commit bumped the cart's stamp before the fact went out.
- **The topic** is one name, `Store::CATALOG_TOPIC`, passed to both sides as configuration; the
  checkout's is per cart, `Checkout.topic(cart_id)`, used only by its own screen.
- **Subscription outputs are configuration.** `Foundation::Ports` reads a part's outputs through `outputs`, the
  class's by default; `Subscription` answers one per configured kind, so `feed.stock` is a port the wiring
  test, the drawing and the trace all see.

What it changed: `LiveUpdate` and its three rendered broadcasts are gone, and so are the screens'
render lambdas for them. `CartLines`, `SavedItems` and `Wishlist` gained a `product` input ({
product_id: }, asked again; the lines redraw and reprice the lines that hold it), which the
`OrderLines` feature forwards. Four `live` routes and actions (products has a second, `live_row`, for
the product page). The staff-edit gap closed with the cart's `product` kind and its wire to the
order; the portal's catalogue row is no longer replaced with the staff row. Fourteen tests: the feed,
the format and the sink on their ports (`test/ala/change_feed_test.rb`), the three `product` inputs on fakes,
and eight that publish and post facts back to each page (`test/controllers/change_feed_updates_test.rb`);
two browser tests in `test/system/change_feed_test.rb` edit a product in a second session and see the open
list and the open cart change.

The linter's three R11 findings from 2026-10-21 (a step's template chosen by an interpolated name, in
the checkout controller and the checkout and portal pages) are answered with literal tables,
`Checkout::STEP_PARTIALS` and `Portal::STEP_PARTIALS`.

### What it costs

- Every live update is a round trip: the fact arrives, the page posts it back, the page's
  composition answers. `LiveUpdate` rendered once and sent the HTML to every page. Here each open page
  pays a request, and the per-request pages reload their lists from the tables. The topic is coarse
  (every product change on one topic); each page decides by kind, not by product.
- A fact posted back is trusted only to say "look again": the pages re-read through their tables, so a
  forged fact costs a query and changes nothing.
- The product page answers a deleted product with a 404, which the browser half ignores; `LiveUpdate`
  removed the row.
- A fact that arrives before a page's stream is subscribed is lost, as before; the checkout's
  `catch_up` still covers its one case.

## The wiring as it ran, and the checkout kept (2026-10-11)

**Forwarding.** A feature's twelve `on { emit }` lines became two:

```ruby
forward(@lines, :items, :products, :changed, :adding, :rows, :row_added, :row_changed, :row_removed, :contents, :saved, :line)
forward(@undo, pending: :undo_pending)
```

`Foundation::Ports#forward(part, *names, **renamed)` wires each of the part's outputs to a block that
delivers on the feature's output of the same (or the renamed) name, through the same `deliver` that
`emit` and `ask` use, so a request/response output is answered by whoever the feature is wired to.
The drawing is unchanged: a forwarded inner output lands on the feature's subgraph, as a block does.

**The running trace.** `Foundation::Trace` is a table of hops, counted by the sender's class, the
output, the class of what it reached (or `block`) and the input, filled by `Ports#deliver` while the
trace is on. The test helper turns it on and, after the suite:

- `ProgrammingParadigms::Drawing.running(screen)` draws a freshly built screen's graph with the wires
  the trace saw carry something solid and the rest dotted, into `docs/diagrams/running/`;
- `Drawing.unfired(screen)` lists the wires no hop matched, and the run exits non-zero if any is not
  in the helper's `UNEXERCISED` list and the run was the whole suite (a single file is reported, not
  enforced).

The match is by class, output, target class and input, not by instance: a wire that carried
something in one screen counts for the same wire in another, and a domain test's hops count too.
That is coarser than V51B's per-page hops and precise enough to find what it found. Its first run
reported four wires: the cart's `wishlist.dropped` (no test took a wishlisted item off from the
cart line; one does now) and the checkout's three write wires from its `CartLines` to its store,
which could never fire because the checkout only reads the lines. Those three wires are gone and the
ports are listed as grounded in the wiring test. V51B found the same kind of thing on its first run.

**The checkout, kept.** V04 kept the cart and left the checkout per request because its payment ran
in a job that rebuilt the screen. Now `LongLived` registries have names (`LongLived.register(:checkout_screens, ...)`,
`LongLived.named(:checkout_screens)`), and `PushLater.port_for(:checkout_screens, cart_id, :charge)`
enqueues a push that the job delivers with `LongLived.named(registry).with(key)`. In the web process
the job finds the kept composition; in a separate job process it builds one, which reloads from the
stores, delivers, and bumps the stamp so the web process reloads on its next request (until
2026-10-19 that reload missed the flow's step; see "Other writers" below). The `Checkout`
and `Order` models bump the cart's stamp like the line models. The checkout screen gained `reload`
and `begin`, lost the loads in front of every input, and its controller renders inside the
composition's turn, with the two step branches in private methods rather than in the wiring block
(the linter's R11 asked, and the branch is the controller's routing, not the composition's logic).

The portal stays per request, on purpose: it is the demonstration that the same feature serves a
composition that is rebuilt.

### What it costs

- The trace's match is by class, so a wire can be marked fired by another screen's identical wire.
  The structural drawing and the wiring test are per instance; the two reports are read together.
- A full run is detected by every test file under `test/ala` and `test/controllers` having loaded,
  so the system suite and a single file never fail on coverage.
- One more process-wide table (`LongLived`'s registries by name), accepted under R2 as the execution
  model's own, where §3.10.2 puts the arbitrator.
- The checkout's controller has two private methods whose only job is to choose a redirect or a
  render from the flow's step: Rails' form, kept out of the wiring block.

## A feature, placed by two pages (new in V05)

Spray's Features layer (§2.2) holds compositions of domain abstractions that a user story needs
together, reused across applications or, here, across pages. V04's cart and portal screens each
built a `CartLines` and an `Undo` and wired the same five wires between them and their store. V05
moves those into `Features::OrderLines`:

```ruby
# inside the feature: a value and an undo, wired to each other, their outputs forwarded as the feature's
@lines.wire_to(@undo, from: :removed, to: :capture)
@lines.on(:products) { |ids| ask(:products, ids) }     # a request passed up to whoever the page wires
@lines.on(:row_changed) { emit(:row_changed, _1) }
@undo.on(:restored) { |id| emit(:fetch, id); emit(:restored, id) }

# the cart page places it, kept across requests, with its row and window
@order = Features::OrderLines.new(cart_id:, undo_lines: CartItem, undo_window: Store::UNDO_WINDOW, row: LineRow.new(fields: %i[...], links: ->(id) { ... cart URLs ... }))
@order.wire_to(@items, from: :items, to: :lookup)
@order.wire_to(@totals, from: :contents, to: :contents)          # CartTotals, with pricing choices
@order.wire_to(patch(:replace, ->(row) { dom.cart_line_id(row[:id]) }, line_html), from: :row_changed)

# the portal page places it, per request, with its row and a longer window
@order = Features::OrderLines.new(cart_id:, undo_lines: CartItem, undo_window: Store::PORTAL_UNDO_WINDOW, row: LineRow.new(fields: %i[...], links: ->(id) { ... portal URLs ... }))
@order.wire_to(@totals, from: :contents, to: :contents)          # OrderTotals, with volume tiers
@flow.wire_to(@order, from: :lines, to: :lines)                  # the submit flow asks it for the lines
```

What makes it a feature and not a helper:

- **Ports, not methods.** The feature has fourteen outputs and thirteen inputs and no other public
  surface beyond `parts`. A page wires it the way it wires a domain abstraction; the Foundation's
  `wire_to` and `on` are the whole mechanism, with `ask` and `emit` inside the feature forwarding
  an inner port to an outer one. A request/response output is forwarded the same way (`on(:products)
  { ask(:products, _1) }`), so the feature asks its page's product index without knowing it.
- **Configuration, not knowledge.** The two pages differ in rows (fields and links), window, totals and what the
  page does with `saved` and `line` (the cart wires them to saved-for-later and the wishlist; the
  portal leaves them open, listed in the wiring test). The feature knows none of that.
- **It composes.** The cart's long-lived composition keeps the feature between requests exactly as
  it kept the two parts; the portal's per-request screen loads it before each input exactly as
  before. The execution models did not change.
- **The drawing walks in.** `Foundation::Ports#parts` is `{}` for a leaf and the feature's two parts
  for the feature, so `Drawing` draws a feature as a Mermaid subgraph with its inner wires, and the
  wiring test checks that every inner output is wired. Both run on the built object graph.

Where the Elixir variants stand on the same question: V51's `UndoRemoval` story is already shared by
the cart and the portal pages, each with its own window, while editing is two stories (`EditCart`,
`EditOrder`). V05 is the Rails counterpart with the editing included, which is the larger reuse.

### What it costs

- Forwarding: twelve `on { emit }` lines that say "this inner output is my output". A port-aliasing
  facility in the Foundation would make them one line each; it was not added, so the feature's
  wiring is the same vocabulary as a page's.
- The checkout page still builds a bare `CartLines` (it has no undo); a feature that fits two of
  three pages is a feature, not a layer rule.
- A new layer in `.ala_lint.rb` between application and domain, so a feature may depend down on
  domain abstractions and a page may depend on features and on domain abstractions alike. The
  linter made no finding on the feature itself; its one finding during the build was in `Drawing`
  (a `respond_to?(:parts)` duck-type on a collaborator, R9), fixed by giving every ported object a
  `parts` message in the Foundation.

## The composition lives across requests (V04)

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

`LongLived` is an execution model in the paradigms layer, beside `PushLater` and `ChangeFeed`: it
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
  (cart_id) }` in the four line models, accepted under R1 as the store's own stamp, not a decision;
  a product bumps every open cart that shows it, below).
  The registry reads the stamp as each request starts, sends `reload` when it moved, and keeps that
  reading as seen, so any bump after it (the request's own included) reloads the next request. A
  composition kept by another process sees the bump on its next request: no cache invalidation bus,
  one integer column.
- **Across processes, what holds and what is assumed.** Each process (every Puma worker, the Solid
  Queue worker) keeps its own table; nothing is shared but the database. Safe: every write a kept
  composition reads goes through a model that bumps the cart (the four line models, `Checkout` and
  `Order`; the portal's `OrderSubmission` does not and need not, the portal being rebuilt per
  request) and every product write bumps the open carts that show the product, so another process's
  composition reloads before its next use. The guarantee: a bump that commits after a request's stamp
  read, by anyone, is never recorded as seen, so the next request on that key reloads; one that
  commits before the read is seen by that request's `reload`. The cost is that a request that wrote
  makes the next one reload too. Assumed: a request sees a consistent
  cart only after `with`'s stamp check, so nothing reads a kept composition outside `with`; `reload`
  re-reads *everything* a part keeps from a store, or that part goes stale silently; and what a
  part keeps without a store (the checkout's `done`, a flash) is this process's only. Not covered:
  any other table a kept part might come to read without a model that bumps the carts it affects.
  *Fixed 2026-10-19:* product writes moved no cart's stamp, so a kept cart showed, and a kept checkout
  charged, a price as it last loaded (in one process as much as across several). `Product`'s
  `after_commit { Cart.bump(Cart.holding(id)) }` bumps, in one `UPDATE`, every open cart with the
  product on a line (an undoable removal included, since `Undo` fetches it back), saved or
  wishlisted; the same R1 acceptance as the line models. Completed carts are left: their price was
  charged and no page shows it again, and their lines would make every edit touch the store's whole
  history. Settlement's `decrement_stock` was an `update_all`, invisible to callbacks; it now locks the
  row and saves the record, so taking stock moves the badge on other kept carts too. Every kept part
  that shows a product (`CartLines`, `SavedItems`, `Wishlist`, the checkout's `CartLines`) already
  asks `ProductIndex` again in `load`, so `reload` needed nothing new. Four tests in
  `ProductChangesTest` hold the kept instance and see it re-read.
  *Fixed 2026-10-19:* the checkout's `reload` re-read its lines and pricing but not its flow's
  `PersistedSteps`, which keeps its record; with the payment job in another process the step moved
  and the stamp with it, yet the web process's checkout kept answering "processing" (204 from
  `status`). `PersistedSteps#reload` reads the record again and the flow's `load` input sends it;
  `CheckoutTest` delivers the payment through a second `LongLived` the way a job process would.
  *Fixed 2026-10-19:* `with` recorded as seen the stamp read *after* the request, so the request's
  own bumps would not force a reload. A bump by another writer (another worker, a job, a product
  edit) committed during the request was recorded with them, and the kept composition missed it
  until some later bump. A `version` lambda cannot tell whose a bump was; counting the request's own
  bumps would need per-thread state in `Cart.bump` that `LongLived` reads (an R2 channel between the
  store and the execution model) and would still trust that every write the request made is in the
  composition's memory. `with` now keeps the reading taken before the request. A request that wrote
  costs the next request a `reload`: on a one-line cart a GET after a change runs 11 queries instead
  of 5, while every request runs one fewer (no second version read). One test in `LongLivedTest`
  (replacing "a version moved by the request itself is not stale", which asserted the race) and one in
  `ProductChangesTest` change a product during another turn.
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
  The request after a change reloads, though, since the registry cannot tell its own bump from
  another writer's (above): only a run of GETs avoids the stores.
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
| **rules** | `Rules::*` (pure: pricing, shipping, promo, volume tier, stock status, line items, the product projection and a held line's row), `views/elements/` (generic UI: a product line, a stock badge, tabs, a modal, milestones, a record form) | significantly more general than the domain: they take any input and know no store |
| **paradigms** | `DataFlow`, `Event`, `RequestResponse`, `Transitions`, `PersistedSteps` (a state machine kept in a record), `ChangeFeed` (outside change: a publish sink, a subscription part, their fact format; `LiveUpdate`, a broadcast sink, until 2026-10-21), `PushLater` (an asynchronous execution model) | how a connection runs |
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
component knows a route and no page computes one per row. Since 2026-10-19 the lambda goes in a
`Rules::LineRow` with the product fields the page's partial reads, one projection the three lists
share where each had written its own. The cart line takes the wishlist's ids
and marks itself; the tabs element takes counts and words and writes its labels.

**Names flow down (R5).** `Foundation::DomTargets` (the DOM ids and marker classes live updates
target) is declared with `helper` so elements render them and screens broadcast to them, both
depending down. The checkout's status target and the modal's frame name are screen constants the
pages pass to the components as locals.

**Execution models in the paradigms layer (R1).** `LiveUpdate` (now `ChangeFeed`) and `PushLater` use `DataFlow`, so
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

After the build: 70 + 5 tests green, 0 wires unfired after the full suite, RuboCop clean, `ala_lint`
100/100 at every tier with nine accepted lines. V02's, V03's and V04's walks hold; what V05 adds or
changes:

| Rule | Verdict | Evidence |
|---|---|---|
| R8 | met, better | the picture is drawn from the built graph and marked by the run: a wire that never carried anything is dotted in the drawing and listed by the suite, which failed the first time |
| R6 | met | `forward` is one Foundation word for "this part's output is mine"; a feature's wiring reads as a page's |
| R9 | met | the job names a registry, not a screen class; `LongLived.named` is the paradigm's own message, so nothing reads global configuration to find a collaborator |
| R2 | met, accepted | the registries' table is class-level state in the execution model, listed and reasoned |

What the first V05 build added:

| Rule | Verdict | Evidence |
|---|---|---|
| R1 | met | the feature depends on two domain abstractions and the Foundation; the two pages depend on it; nothing in the domain knows it exists |
| R9 | met | one owned interface, ports; `respond_to?` on a peer was the build's one finding and is gone |
| R3 | met | the row (fields and links), window and the undo store are configuration; the portal's longer window is a `Store` constant with its reason |
| R6 | met | the feature's header comment lists every port; the forwarding lines are wiring, not logic |
| R8 | met, better | the two pages' wiring reads as "place the order lines, give them a store, totals and patches"; the drawing shows the feature as one box that opens |

What V04 added:

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
