# V01 design: wired screens

A Rails app whose pages are per-request compositions of domain abstractions wired port to port
(Spray's own form, §1.6.5), with Rails' controllers, views, models, Turbo and Active Job doing what
they usually do around it. This document records the design, the choices between a Rails habit and
the checklist, and a walk of the Ruby edition of the ALA Checklist.

## At a glance

| | |
|---|---|
| Composition layer | one `Screens::*` class per page, built per request (and once more inside a job) |
| Wiring form | `wire_to` / `wire_in` between instances, `on` for a lambda at the wire, read top to bottom in the screen's constructor |
| Where state lives | Postgres, one table per feature against the cart id; the browser keeps only UI state (which tab) |
| Ports | `output` (a private ivar the wiring fills) and `input` (a private handler the paradigm wraps in a port object); `emit` and `ask` inside a class |
| Paradigms | push `DataFlow`, `Event`, `RequestResponse` (pull), `Transitions` |
| Live updates | `Foundation::LiveUpdate` sinks the screens wire; pages `turbo_stream_from` a stream |
| Async | `Foundation::PushLater`: a job that rebuilds the screen by name and pushes an input |
| Checks | a coverage test per screen (`unwired_outputs`, minus ports left open on purpose); integration tests ported from the Elixir variants |

## The request cycle

1. The controller builds the page's screen with the session's cart id (`Screens::Cart.new(cart_id:)`).
   The constructor creates the domain instances, configures them from `Screens::Store`, and wires
   them. Nothing has run yet.
2. The controller pushes one input (`screen.input_port(:remove).push(id)`). Outputs flow along the
   wires: a removed line reaches `Undo.capture`; a restored one makes the screen say "Item restored";
   a summary lands in `@summary`.
3. The controller redirects (after a change) with the screen's flash, or renders (on a GET) the
   view, which reads the landed values from the screen.

Because the composition is rebuilt per request, every instance that holds state keeps it in a store
it is configured with (`CartLines` on `CartItem`, `Undo` on the same table's `removed_at`,
`CheckoutFlow` on `checkouts`). `CartTotals` is the exception: it joins three flows within one request
and keeps nothing.

## What a LiveView process held, and where it went

| In the Elixir variants | Here |
|---|---|
| gift-wrap marks, in the cart's state | `cart_items.gift_wrapped` |
| the undo offer and its 5 s timer | `cart_items.removed_at`; a Stimulus countdown posts `expire`; `Undo.load` purges past-window rows as the backstop (R4.3 holds without the browser) |
| saved items, wishlist | `saved_items`, `wishlist_items` |
| promo code, shipping method | `cart_pricing_choices` |
| checkout step and address; portal step and PO | `checkouts`, `order_submissions`, each a step machine over `Transitions` |
| the payment task and `handle_async` | `PushLater` job → `Screens::Checkout#charge` → `Charge` → `SettleOrder` + `CheckoutFlow.succeeded`; a `LiveUpdate` replaces `#checkout_status`, whose complete state carries a Stimulus `visit` to the success page |
| PubSub stock facts re-rendering each row | `LiveUpdate` broadcasts the `stock_badge` to every element marked `.stock_<id>`; catalog rows are appended/replaced on save |
| the active tab | the `tabs` Stimulus controller; UI state only (R3.7) |

## Rails choices against the checklist

- **Controllers forward; screens compose.** An action decodes params, pushes one input, and
  redirects or renders. The two places a controller branches (`if screen.saved`, `if screen.step
  == :payment`) route an outcome to a response, which R11 reads as routing, not logic.
- **Models are persistence, one per feature** (R10). They carry small data-only methods
  (`CartItem.add`, `Product.decrement_stock`, `Order.place`, `Cart.ensure_open`) and no feature
  rules. Address and PO validations live on `Checkout` and `OrderSubmission` with contexts, and their
  messages in `config/locales/en.yml`, as the checklist's Rails table suggests.
- **`Product` validates name and amount.** R2.2 states it, and it is intrinsic to a product record;
  a stricter reading would move it to the composition.
- **Broadcasts are wired, never model callbacks.** `Screens::Catalog` wires `Records.saved` to a
  `LiveUpdate`; `Screens::Checkout` wires `SettleOrder.stock_changed` to one. No `after_commit`.
- **No DI container, no service objects, no concerns on models.** The two controller concerns
  (`CartScreen`, `PortalScreen`) only build the screen and redirect.
- **Live validation** posts the form to a `validate` action that answers a Turbo Stream replacing the
  form (`live_validate_controller.js`, which must send the page's CSRF token because Rails 8's
  per-form tokens are bound to the form's own action).
- **Modal forms** use a `modal` Turbo frame on the list page and submit with `data-turbo-frame="_top"`,
  so a successful save is an ordinary redirect with a flash.
- **Changes redirect; Turbo morphs.** Every change is a `button_to` or small form that redirects to
  the page, which the layout refreshes by morph. This is the most ordinary Rails shape and it keeps
  the controllers to one line each; the cost is a full render per change, which Turbo's morph hides.
- **One `cart_items` table serves both the storefront and the portal.** It is the "lines" abstraction
  both build on (v51's `Lines`); the portal never reads `gift_wrapped`. A stricter R10 reading would
  give the portal its own lines table.
- **Agreed DOM names live in one helper** (`LiveTargetsHelper`): components render them, screens
  broadcast to them, so neither side holds a literal (R5).
- **`Screens::Store`** holds every number and word that makes this store this store (R3): rates,
  codes, tiers, thresholds, labels, form fields. Screens pass values down; nothing below reads it.
- **Threads.** Puma serves requests on threads; every stateful instance is built per request and
  used on one thread (§3.9). The job rebuilds its own screen. Nothing shares an object across threads.

## Where the shape costs something

- A page needs a screen class plus small controllers, so a feature touches more files than a
  `rails g scaffold` would. The screens are 60–90 lines each; the controllers 10–40.
- `wire_to` and `on` are a vocabulary a Rails team hasn't met. Everything else (models, controllers,
  partials, Stimulus, Active Job, Turbo Streams) is stock Rails.
- The undo window depends on the browser posting `expire`; without it the removal is still finalized
  on the next load, but the banner stays until then.
- A shopper who reloads `/cart/checkout/payment` after a completed payment sees the new (empty)
  cart's checkout rather than the success page; the live update normally sends them on before that.

## Checklist walk (Ruby edition, by hand)

| Rule | Verdict | Evidence, and what to look at |
|---|---|---|
| R1 edges drop | met | domain classes reference only paradigms, Foundation, Money and the model they are configured with; no domain class names another; `grep -rn "DomainAbstractions::" app/ala/domain_abstractions` finds only `CheckoutFlow → CheckStock` and `CartTotals/OrderTotals → Pricing`, both plain rules one layer down |
| R2 no shared mutable state | met | values on wires are hashes built per call; no class-level mutable state; each request builds its own instances |
| R3 literals at the composition | met | `Screens::Store`, the screens' `TEXTS`, `FLOW`, `MILESTONES`; the domain holds no product number or word; the one default (`shipping_method: :standard`) is passed in by the screens |
| R4 state with its owner | met | every stateful instance owns a store and reads only its own table; the screens hold only landed values |
| R5 no silent contracts | met, one agreed module | DOM names through `LiveTargetsHelper`; event/URL names are Rails routes; `"cart_id"` in charge metadata appears once (`Screens::Checkout`) |
| R6 nameable | met | each class names one concept and says its ports and configuration in its header comment |
| R7 earns its existence | met, with one judgement | `OrderTotals` beside `CartTotals` (different pricing); `ProductRow` is a one-call projection used by three screens; nothing forwards |
| R8 reads as requirements | judgement | a screen's constructor reads top to bottom as the page's wiring; the coverage test lists every port left open |
| R9 ports by paradigm | met | all ports are `DataFlow`, `Event` or `RequestResponse`; the gateway is configuration; no class exposes port methods publicly (`emit`/`ask` are private, handlers are private) |
| R10 no shared entity | met, one noted share | per-feature tables; `cart_items` is the shared lines abstraction (above) |
| R11 composition only | met, with routing departures | screens wire and land; controllers route outcomes; templates loop over projected rows and read one boolean (`disabled: @s.summary[:empty]`); `components/_checkout_status` holds a `case` as a UI abstraction's own logic |

Not scored: no OO linter has run on this code.
