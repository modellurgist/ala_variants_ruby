# V01 under ala_lint_ruby: findings and the changes they suggest

Run on 2026-10-05 with `../../ala_lint_ruby/bin/ala_lint --root .` and the layer map in
`.ala_lint.rb` (application > domain > paradigms > foundation; models in foundation; `Cart` the
identity model). Nothing here has been applied; each item is a change to decide on.

| tier | score | rules met | functions clean |
|---|---|---|---|
| default | 65/100 (C) | 6 of 10 checked | 188/200 (94%, A) |
| `--strict` | 60/100 (C) | 5 of 10 | 188/200 |
| `--super-strict` | 53/100 (D) | 4 of 10 | 178/200 (89%, B) |

The density is low (24 scored findings over 200 functions) but concentrated: R1 holds 18 of them,
all of one of three kinds.

## Scored findings (default tier)

### R1: component partials that render or call peers (8)

`_cart_line`, `_order_line` and `_catalog_order_row` render `components/product_line`;
`_product_row` renders `components/stock_badge`; four components call `LiveTargetsHelper`. In the
declared map every component and the helper sit in the domain layer, so each is a cross-peer edge.

- **Option A (the checklist's).** The page places both: `carts/show` renders `product_line` and
  passes the cart line's controls as the block, instead of `cart_line` rendering `product_line`.
  Costs a longer page template; removes a layer of components-that-contain-components.
- **Option B.** Declare a UI sub-layer: `components/product_line`, `stock_badge` and
  `LiveTargetsHelper` as a `ui_base` layer under `domain`, so the edges drop. Honest only if those
  three really are more abstract (they are: a product line and a stock badge take any row; the
  helper is names).
- **Option C (for the helper).** Pass the DOM ids in from the page as locals (`id: product_row_id(x)`
  computed in the page), which also settles the R5 reading of agreed names below.

### R1: stateful domain abstractions calling pure rules (7)

`CartTotals#summary` and `OrderTotals#summary` call `Pricing.*` (three calls each);
`CheckoutFlow` calls `CheckStock`. Both ends are in `domain`, so each is a peer edge. DESIGN.md
already called these "plain rules one layer down"; the map doesn't say so.

- **Option A.** Declare the layer the design already assumes: a `rules` layer below `domain` holding
  `Pricing`, `CalculateShipping`, `CalculateGiftWrapCost`, `ValidatePromo`, `VolumeTier`,
  `StockStatus`, `CheckStock`, `BuildLineItems`, `ProductRow`. The edges then drop and the map
  matches the prose. (`StockStatus` is already handed down configured by the screens; this makes
  the rest consistent.)
- **Option B.** Keep one domain layer and inject: `CartTotals.new(pricing: Pricing, ...)` from the
  screen. More configuration, no new layer.

### R1: Foundation classes reaching up (3)

`Foundation::LiveUpdate` references `ProgrammingParadigms::DataFlow` (it has a DataFlow input
port) and calls `ApplicationController.render`; `Foundation::PushLater.port_for` builds a
`ProgrammingParadigms::DataFlow` port. A Foundation class naming a paradigm is upward in this map;
naming the application's controller is upward from anywhere.

- `LiveUpdate` and `PushLater` are sinks and execution models that *use* the paradigms: they
  belong in `programming_paradigms` (Spray keeps execution models there) or as domain data-sink
  abstractions, not under Foundation. A move, no code change.
- `LiveUpdate.component` rendering through `ApplicationController.render` is the one real upward
  call. `ApplicationController.renderer` is Rails' documented way to render outside a request; it
  could be `ActionController::Base.render` (a framework constant, not the app's) or the renderer
  could be passed in as configuration by the screen that wires the sink.

### R10: `belongs_to :product` on three line tables (3)

`CartItem`, `SavedItem` and `WishlistItem` each `belongs_to :product`, and `CartItem.active`
`includes(:product)`: the storefront's lines read the catalog's record (name, amount, stock,
thumbnail) through the association. Under §6.17.2 that is a feature reading another feature's data;
under the "identity key" technique the lines would hold `product_id` and the screen would resolve a
product projection and pass it in, or the catalog would expose a read-only projection the lines
feature is configured with.

- If `Product` is read as the shared identity (like `Cart`), add it to `identity_models` and the
  finding goes away; the honest reading is that it isn't, because the lines read its columns.
- The ALA shape: `CartLines` takes a `products` projection (id → {name, amount, stock}) as a
  configured source, and the models drop the association. Also removes the `includes`.

### R5: two agreed names (2)

- `"checkout_status"`: `Screens::Checkout` broadcasts to it and `components/_checkout_status`
  renders `id="checkout_status"`. Pass the id in as a local from the screen (the component then has
  no name of its own), or add it to `LiveTargetsHelper` like the other targets.
- `"modal"`: `components/_modal` names its Turbo frame and `products/index` and `products/show`
  name it in `data-turbo-frame`. Both pages are the composition, the component isn't; pass the frame
  name to the component as a local.

### R3: one literal (1)

`Foundation::LedgerGateway#charge` uses `SecureRandom.hex(6)`. Intrinsic (a reference length), not
an application literal. Keep; the linter can't know.

## Advisory findings worth acting on

- **ports (11).** Every domain abstraction's header lists its output ports and configuration but not
  its input ports (`CartLines`: load, bump, set_quantity, remove, save_for_later, receive,
  toggle_gift_wrap; `Undo`: capture, restore, expire; and so on). Spray lists all ports in the header
  (§5.8.2). A one-line "Ports in: …" per class.
- **ports_unwired (2).** `SettleOrder.settled` and `Undo.expired` are wired by no screen; the wiring
  test lists them as deliberately open. Either wire `expired` to a flash ("Removal is final") or
  delete the two ports.
- **r11 (15, super-strict).** Two branches in `Screens::Catalog`'s wiring blocks (`if
  record.persisted?`, and the created/updated notice ternary), the `||` fallbacks in
  `ApplicationController#current_cart_id`/`current_portal_cart_id`, `PortalsController#submit`'s
  `if` (the else arm pushes a second input, so it isn't pure routing), and nine template findings:
  `each` loops in `carts/show`, `portals/_lines`, `portals/show`, `products/index`; an `include?` in
  `carts/show`; `persisted?` ternaries in `products/_form` and `form_again`. The checklist's moves:
  `render collection:` or a rows component for the loops; `wishlisted:` carried on the row; a
  `title:` passed by the controller instead of the `persisted?` branch; the notice text chosen by
  `Records` emitting `created`/`updated` as two outputs the screen wires to two notices.
- **app_share (43%).** Controllers' actions and templates are counted as composition functions. A
  ratio, not a defect; Spray's 3–10% was measured on wiring code, not on a framework's handlers.
- **module_avg (17 lines).** The domain classes average 17 lines; the one-rule classes are
  deliberately small. Read with the design, as the message says.

## Precision notes (what the linter got wrong on the way, now fixed)

Recorded so the heuristics stay honest: markup strings under `.freeze` were read as Ruby text;
`"components/product_line"` as a render path was counted as a contract; `run` was a "meaningless"
name; `ApplicationRecord` subclasses were own-class inheritance; `Foundation::ApplicationJob`
resolved to the `Foundation` unit; paradigm modules with an inner `Port = Data.define` were data
types; `session[:x] = ...` was handled data; controller view fields were R4 state. Each has a test.
