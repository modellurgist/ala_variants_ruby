# V09 design: ports only at variation points

## The rule

V09 is V08 reshaped by "ALA Light, subset 3" (`../../ala_lab/docs/Q-ala-light-subsets.md`). This is
a reading of the checklist, not Spray's wording:

- **A variation point is a part placed by two or more compositions today, or a programming
  paradigm** (the wiring itself, the `ChangeFeed`, the step and transition machinery). Only
  variation points keep declared outputs and are wired. A part that might get a second wiring
  later does not count. The test is a second placement today, so the rule can be checked from the
  code.
- **Every other part is called.** It keeps its layer and the configuration the page gives it, with
  literals still at the composition (R3). The page calls it and uses what it returns. There are no
  output ports, no wire arm, and no relay of its result through other parts. A stateful part placed
  once becomes a value the page holds and calls.
- **A feature placed by one page folds into that page.** No feature here is placed once.
- **A part that would now be a one-call wrapper is inlined into its caller's layer** (R7).
- The rest holds as in V08: R1, R3, R6, R7 and R8 are scored or read, and R11 is advisory.

Why: the Light change sequence (`../../ala_lab/docs/change-cost-light-2026-10-22.md`) found that
subset 2 cost as much as strict ALA, and that its dearest step paid the port tax on parts placed
once. A priced summary had to travel by wire through `SettleOrder`, `SubmitOrder` and the two state
machines to reach the code that writes the order.

## Inventory

Every part in V08 that declared outputs or that a page ran through `wire`, and who places it:

| Part | Layer | Placed by | Variation point | In V09 |
|---|---|---|---|---|
| `Features::OrderLines` | features | Cart, Portal | yes | wired |
| `CartLines` | domain | OrderLines, Checkout | yes | wired |
| `CartItemsStore` | domain | Cart, Portal, Checkout | yes | wired |
| `AddLine` | domain | Catalog, Portal | yes | wired |
| `Records` | domain | Catalog, Portal | yes | wired |
| `CartTotals` | domain | Cart, Checkout | yes | wired |
| `PricingChoices` | domain | Cart, Checkout | yes | wired |
| `ChangeFeed::Subscription`, `ChangeFeed::Publish` | paradigms | every page; Catalog, Checkout | paradigm | wired |
| `StepRecord` (over `Transitions`) | paradigms | Checkout, Portal | paradigm | called, as it was; now also by the pages |
| `Undo` | domain | OrderLines | no | called inside the feature |
| `CheckoutFlow` | domain | Checkout | no | called; its four one-call wrappers removed |
| `Charge` | domain | Checkout | no | called |
| `SettleOrder` | domain | Checkout | no | called |
| `SubmitOrder` | domain | Portal | no | called; its three one-call wrappers removed |
| `OrderTotals` | domain | Portal | no | called, and stateless |
| `SavedItems` | domain | Cart | no | inlined: the page holds a `HeldProducts` |
| `Wishlist` | domain | Cart | no | inlined: the page holds a `HeldProducts`, the toggle is on the page |
| `SavedItemsStore`, `WishlistStore` | domain | Cart | no | called; `apply(op)` became verbs |
| `ProductIndex` | domain | Cart, Checkout, Portal (twice), Catalog | yes, but a pull | called, as it always was |

`ProductIndex` never had ports. A page hands its `lookup` to `HeldProducts` as a lambda, which is a
pull (§4.4.3).

## What changed

- **`OrderLines`** wires only `CartLines`. Its inputs call `Undo` and send what it answers
  (`load`, `capture` and `expire` answer whether a removal can be undone; `restore` answers the line
  or nil). The feature's outputs are unchanged, so neither page's arms for it changed.
- **Checkout.** `pay` matches on what `CheckoutFlow#pay` answers (`{ blocked: }` or `{ payment: }`)
  and pushes the job. The job's `charge` input matches on `Charge` (`[:charged, reference]` or
  `[:declined, reason]`), runs a stock sink for each level `SettleOrder` answers, then the flow and
  the outcome sink. `show`, `validate`, `submit_address` and `edit_address` call the page's
  `StepRecord` with the page's own events and context. `CheckoutFlow` kept these as one-call
  renames, and as call-and-return they were passthroughs. The flow keeps `start`, `pay`, `succeeded`
  and `failed`. `step` and `form` are read from the `StepRecord`.
- **Portal.** `OrderTotals#summary(contents)` is called from the `order.contents` arm. `review` and
  `submit` branch on what `SubmitOrder` answers (`:empty`, the placed order). `reference` is
  `SubmitOrder#reference`, and `show`, `edit_lines` and `validate` call the `StepRecord`.
- **Cart.** Saved items and the wishlist are each a `HeldProducts` the page holds. With the
  `changed` relay gone, `SavedItems` was a one-call wrapper on every method, and `Wishlist` was one
  apart from a single branch, so both were inlined (R7). The stores answer verbs (`stash`,
  `remove`, `add`) in place of an op hash, which existed to travel on a wire. The page's three
  wishlist inputs and the `order.line` arm call two private helpers, `toggle_wishlisted` and
  `unwishlist`, plus one pane patch each for saved and wishlist.
- **Catalog**: nothing. Both its parts are placed twice.
- **Tests.** Behavioural tests are unchanged. Four unit and structural tests changed to returned
  values: `Undo` returns, `CheckoutFlow` (now asserting `start`'s `:empty`, `pay`'s
  `:out_of_stock` and the payment), and the two drawing tests (a called part is not drawn). 101 runs
  as before, 508 assertions (V08: 498).

**Differences in behaviour, none observable to a test or a user:**

- The portal's `show` no longer sets the screen's `flash[:notice]` at the submitted step. V08 set it
  through the shared `reference` arm, but no controller reads the screen's flash on `show`.
- The checkout screen no longer has `done`, which nothing read.
- After "move to cart", the response's saved-pane patch comes before the order's patches instead of
  last. Turbo applies each patch to its own target, so the order does not matter.
- "Add to cart" from the wishlist still renders the new cart row while the product is still in the
  wishlist, so the row shows the filled heart and the Wishlist tab keeps its old count until the
  next load. That was V08's behaviour, an artefact of its arm order. V09 keeps it on purpose (the
  order of calls in `add_wishlisted`) rather than fix it unasked.

## What it costs, and what it buys

- **Buys:** a value reaches a part placed once as an argument. The S04-style change (record what was
  charged when settling) is now `@settle.settle(reference, summary)` on one page, not a new output
  threaded through three arms. Production Ruby is 1973 lines against V08's 2017. The domain layer
  lost 2 classes and 113 lines (526 to 413), the feature gained 8 and the pages grew from 481 to 542.
- **The drawing loses the called parts.** `docs/diagrams/checkout.md` now shows the three publish
  sinks unconnected, because they run from the `charge` input, not from an arm. The running drawing
  shows them as `outside -- request --> publish_*`. The payment path is readable only in the page's
  `charge` method. The structural and running coverage checks still pass, but they now cover only
  the wired parts: 0 of the remaining declared outputs go unrouted.
- **More logic on the pages.** R11 reports 21 findings (V08: 2), and the share of composition
  functions holding logic rose from 1% to 7% (11 of 151). Each is a branch on what a called part
  answered, a `.each` over the stock levels, or a store read handed to a held list. That is the
  intended shape of subset 3: a call-and-return replaces an outcome sent on two ports.
  *Since 2026-10-23* `.ala_lint.rb` sets `r11: { calls: :wired_only }`, which leaves out R11's
  hand-off findings into a called part (a part no composition wires). R11 now reports 11: the 7
  branches, the `.each`, the two `VOLUME_TIER` findings, and one read of the literal `BLOCKED` table.
- **The port tax stays where a part is shared.** The checkout still grounds 9 of `CartLines`' 10
  outputs and both of `PricingChoices`' promo outputs. Those two parts are placed by the cart too,
  so they keep their ports even where only one output is used.
- **Judgement in the rule.** Whether `SavedItems` and `Wishlist` should be called values or inlined
  is an R7 call. `Wishlist#load` would have been a bare delegation, which the passthrough check
  scores at `--strict`.

## Lint: what the new shape tripped

All three tiers score 100/100 with no scored finding. No check was moved to advisory and no
`ala:accept` line was added. The one V08 had, on `CheckoutFlow#show`, went with that method.

- **Scored, fixed by reshaping:** two `passthrough` findings appeared once the checkout called its
  flow: `Screens::Checkout#validate delegates to @flow.validate unchanged` and `#submit_address
  delegates to @flow.submit_address unchanged: expected where delegation replaces inheritance
  (§7.16), proliferation otherwise (R7)`. The fix was R7: the flow's one-call renames went, and the
  page calls its `StepRecord` with its own words. `Wishlist#load` would have tripped the same
  check, and was inlined with the rest of `Wishlist`.
- **Advisory R11 (reported, not scored), 19 new:**
  - "passes X straight into Y: the composition handling data between abstractions", 11 of them:
    `Cart#load` (twice, a store's `lookup` into a held list), `Cart#saved_changed` (three),
    `Cart#wishlist_changed` (two), `Checkout#start` (twice, including "hands blocked (one
    abstraction's result) to []"), `Checkout#pay`, `Portal#review`.
  - "branches (if / casematch): logic in the composition", 7 of them: `Cart#toggle_wishlisted`,
    `Cart#unwishlist`, `Checkout#start`, `Checkout#pay`, `Checkout#charge`, `Portal#review`,
    `Portal#submit`.
  - "iterates (each)", 1: `Checkout#charge`, over the stock levels `SettleOrder` answers.
  - The two `VOLUME_TIER` findings are V08's.
- **Reported:** `clone_inside`, `Cart#saved_changed` and `Cart#wishlist_changed` (18 of 19 nodes:
  two pane patches). `app_share` is 40% (V08: 36%) and `r11_share` 7% (V08: 1%).

## Inherited: V08's Light reading

V08 read R11 (no logic in a composition) as advice, not a score, and moved the one rule a single
page used, `Rules::VolumeTier`, onto the portal as the `VOLUME_TIER` lambda handed to `OrderTotals`.
V09 keeps both: `.ala_lint.rb` still reads R11 as advisory (with `calls: :wired_only` since 2026-10-23). Spray's basis is his own
exception, kept in the application layer because "all the code in the application is specific to
the application requirements" (§6.28.1, §6.28.3).

## Inherited: V07's design, a feature in plain Ruby

V06's design (`../v06-plain-rails/DESIGN.md`) with Spray's Features layer added in V06's own
vocabulary, and one feature in it placed by two pages. This document records what V07 adds, why,
what it costs, and the hand walk after the build.

### Why

V05 built a feature placed by two pages over the Ports foundation, with `forward` lines to make its
parts' outputs its own, and rated familiarity 3 with V04's kept compositions underneath. V06 dropped
the foundation and reached 5. The question V07 answers is whether the Features layer can be added
to V06's shape without losing more than one point.

### The shape

**A feature is a composition that is itself a part.** It includes the same `Wiring` a screen does,
names its parts, and wires them in its own `wire`. What V06 lacked was a way for a composition's
arms to say "this leaves me": a screen lands an output on itself, but a feature has a page above
it that wants the output back. Two words in `Wiring` do it:

```ruby
def collect
  saved, @out = @out, []
  yield
  @out
ensure
  @out = saved
end

def out(output, payload) = (@out << [ output, payload ]; nil)
```

A feature's input wraps its runs in `collect` and returns the buffer; an arm that says `out`
appends to it. The page runs the feature as it runs a part, and the pairs that come back are the
feature's outputs. Spray's feature "creates instances of domain abstractions, configures the
instances with feature specific details, and connects them together", and "features can also have
ports and be wired together" (§2.2): the instances are `initialize`, the connections are the arms
that `run`, and the ports are `OUTPUTS` and the arms that `out`.

**One arm for everything that leaves.** `in [ :lines, _ ] | [ :undo, _ ] then out(output, payload)`
says that every output of the two parts not wired inside leaves under its own name. The `_`
pattern is read by the structural test as "every remaining declared output of that part", so the
coverage check still holds per output, and the drawing shows it as one edge labelled "every other
output".

**Two pages place it.** The cart with the storefront's links and a five-second window; the portal
with its own links and ten seconds. The portal grounds the outputs its rows never offer (`saved`,
`line`, the row deltas) in its `GROUNDED`, as V06 already did for the bare value. Neither page's
other arms changed except that `lines` and `undo` became `order`.

**The drawing opens the feature.** `Drawing` takes a built screen now (it needs the parts' classes
to know which are compositions), draws a feature as a subgraph with its inner arms, and sends an
`out` arm's edge to the feature node. `gaps` and `unrouted` walk into features, so the structural
and the running coverage checks cover a feature's inside as well as the page.

### What it cost

- Two more words in `Wiring`, `collect` and `out`, for 14 lines; `Wiring` is 50 lines in all.
- A feature's inputs are one line each, twelve of them, which is the feature's whole interface
  restated once. V05's `forward` did the same for outputs; here outputs cost one arm.
- The linter counted `parts` as a thirteenth public method. It is the paradigm's message, what a
  drawing or a coverage test reads, so the count now leaves it out along with `initialize`.
- The trace records a feature's inner hops under the feature's class, so a feature placed by two
  pages has one running picture for both; the structural drawing is per page.
- No kept compositions: a feature here is rebuilt per request with its page, as V06's parts are.

### Checklist walk (Ruby edition, by hand, at V07's build)

After the build: 60 + 5 tests green, 0 declared outputs unrouted after the full suite (the
feature's inside included), RuboCop clean, `ala_lint` 100/100 at every tier with no finding and no
accepted line. V06's walk holds; what V07 adds:

| Rule | Verdict | Evidence |
|---|---|---|
| R1 | met | the feature depends on two domain abstractions and the paradigm; two pages depend on it; nothing in the domain knows it |
| R9 | met | the feature's interface is the same shape as a part's: methods in, returned pairs out; `collect` and `out` are the paradigm's words, not the feature's |
| R3 | met | links, window and the undo store are configuration; the portal's longer window is a `Store` constant with its reason |
| R6 | met | `out` is the one word for "this leaves me"; the feature's header lists every input and output |
| R8 | met, better | a page's wiring reads "place the order lines, give them a store, totals and patches"; the drawing opens the feature and the suite proves its inside ran |

## Inherited (2026-10-21): outside change as a paradigm

Before, every change made elsewhere had its own machinery: the catalogue's three `LiveUpdate`
sinks rendered the product list's row and broadcast it, and the checkout rendered a stock badge for
every page that shows one. The composition making the change knew every view (R1, R10), and the
portal got the product list's row because the two shared a DOM id.

`ProgrammingParadigms::ChangeFeed` (`change_feed.rb`) makes it one paradigm, built once:

- `ChangeFeed::Publish` is a sink: config `topic`, `kind`, and a `fields` lambda that picks the fact out of
  the payload; in `push`. The catalogue publishes `product_added`, `product_changed`,
  `product_removed` and `stock`; the checkout `stock`, `paid` and `declined`.
- `ChangeFeed::Subscription` is a part a page places: config `topic`, `kinds`, `url`; in `receive`; out one port per
  kind. Its outputs are its configuration, so it answers `outputs` and `Drawing` reads that where a
  part has no `OUTPUTS`.
- `ChangeFeed.encode` and `ChangeFeed.decode` are the fact format, the only thing both ends share with the topic.
  The catalogue topic is `Store::CATALOG_TOPIC`; a checkout's is `Checkout.topic(cart_id)`.
- Delivery: `ChangeFeed::Channel` streams a signed topic; `change_feed_controller.js` posts each fact of a
  listened kind to the page's `url`; `ChangeFeedRefresh#live` hands it to the screen's `live(message)` and
  renders the screen's `Patches`. A page's live behaviour is its feed's arms:
  `in [ :feed, :stock ] then @patches.replace_all(...)`. The cart, portal and catalogue arms patch
  rows and badges; the checkout patches its status. (In V09 the checkout's three sinks are run from
  its `charge` input, since the charge and the settling are called; the catalogue's still hang on arms.) `catch_up_controller.js` now watches the feed's
  `connected` mark instead of Turbo's stream source.

It costs one request per fact per open page, where Turbo pushed the rendered HTML directly, and
four more ports, one per page's `live`. The feed's arms land on the page as patches rather than
on a part: a page rebuilt per request reads current values through its tables, so there is no
state part to tell.
