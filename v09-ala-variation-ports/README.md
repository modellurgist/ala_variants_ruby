# V09: ALA ports only at variation points

V08 (`../v08-ala-light`) reshaped by "ALA Light, subset 3" (`../../ala_lab/docs/Q-ala-light-subsets.md`):
ports only at real variation points. The Light change sequence of 2026-10-22
(`../../ala_lab/docs/change-cost-light-2026-10-22.md`) found subset 2 no cheaper than strict ALA. Its
dearest step was dear because a value had to travel by wire through parts that only one page
places. V09 removes those wires.

The rule, as this variant reads it. A part placed by two or more compositions today is a variation
point, and so is a programming paradigm (wiring, the `ChangeFeed`, step and transition machinery).
Only variation points keep declared outputs and are wired. Every other part is called. It keeps its
layer and the configuration the page gives it, and the page uses the value it returns. It has no
output ports, no wire arm, and nothing relays its result. A part that would have become a one-call
wrapper is inlined into its caller (R7). The rest of the checklist holds as in V08: R1, R3, R6, R7
and R8, with R11 advisory.

What changed: `Features::OrderLines` (cart and portal) stays wired, and calls its `Undo`. The cart
page calls its saved-items and wishlist stores and holds each list as a `Rules::HeldProducts`;
`SavedItems` and `Wishlist` are gone. The checkout page calls `CheckoutFlow`, `Charge` and
`SettleOrder`, and the portal page calls `SubmitOrder` and `OrderTotals`. Both pages read and move
their own `StepRecord` for the steps that decide nothing. The catalogue page is unchanged. The
inventory and the costs are in `DESIGN.md`.

**Status:** 101 integration and unit tests and 9 Cuprite browser tests, 0 failures. After the full
suite, **0 declared outputs never routed**. RuboCop is clean (114 files, no offenses).
`../../ala_lint_ruby/bin/ala_lint --root .` scores **100/100 with no scored finding** at the default
tier, `--strict` and `--super-strict`, with 10 of 10 rules met, 377 functions (V08 had 382) and no
accepted line (V08's one, on `CheckoutFlow#show`, went with the method). R11 is advisory and, with
`calls: :wired_only` leaving out hand-offs into called parts, reports 11 findings (21 without it; V08:
2), all on the three reshaped pages; `DESIGN.md` lists them. Production Ruby
(`app`, `lib`) is 1973 lines in 72 files, against V08's 2017 in 74.

## Run it

```bash
cd v09-ala-variation-ports              # asdf picks Ruby 4.0.7 from .ruby-version
bin/rails db:create db:schema:load      # Postgres at localhost, user postgres/postgres (see config/database.yml)
bin/rails db:seed
RAILS_ENV=test bin/rails db:schema:load # not db:prepare: its seed data breaks the tests
bin/dev                                 # http://localhost:3000
bin/rails test                          # fails if a declared output never routed
bin/rails test:system
bin/rails ala:diagrams                  # docs/diagrams/*.md from the wire arms, features opened
```

## What's where

As V06 and V07, with:

| Layer | Directory | Holds |
|---|---|---|
| Features | `app/ala/features/` | `OrderLines`: `CartLines` wired inside and `Undo` called; `out` for what leaves; placed by the cart page and the portal page |
| Domain | `app/ala/domain_abstractions/` | wired: `CartLines`, `CartItemsStore`, `AddLine`, `Records`, `CartTotals`, `PricingChoices`; called: `Undo`, `CheckoutFlow`, `Charge`, `SettleOrder`, `SubmitOrder`, `OrderTotals`, `SavedItemsStore`, `WishlistStore`, and `ProductIndex` (a pull, never wired) |
| Rules | `app/ala/rules/` | `HeldProducts` (also the cart's saved and wishlist lists), `LineRequest`, `Pricing.summary` and the configured rules |
| Programming paradigms | `app/ala/programming_paradigms/` | `Wiring`, `Drawing`, `StepRecord`, `Transitions`, `Patches`, `PushLater`, `ChangeFeed` |

## A wired part and a called one, on one page

```ruby
def charge(payment)                        # the job's input on the checkout page
  case @charge.charge(payment)             # called: placed only here
  in [ :charged, reference ]
    @settle.settle(reference).each { run(:publish_stock, @publish_stock.push(_1)) }
    @flow.succeeded(reference)
    run(:publish_paid, @publish_paid.push(reference))
  in [ :declined, reason ]
    @flow.failed(reason)
    run(:publish_declined, @publish_declined.push(reason))
  end
end

def wire(part, output, payload)
  case [ part, output ]
  in [ :lines, :contents ] then run(:totals, @totals.contents(payload))   # wired: the cart places both too
  ...
```

In V08 the same payment went through four wires: `charge.charged` to `settle`, `flow` and
`publish_paid`, and `settle.stock_changed` to `publish_stock`. A value the order writer needs now
reaches it as an argument.

## Inherited from V07 and V08

Outside change is a paradigm, `ProgrammingParadigms::ChangeFeed` (the checklist's "A live
subscription port"). A composition that changes something wires the output to a `ChangeFeed::Publish`
sink configured with a topic and a kind. A page places a `ChangeFeed::Subscription` configured with
its topic and the kinds it listens to, and wires each kind as an output (`feed.stock`). What travels
is a fact keyed by identity (`{ product_id:, stock: }`, `{ cart_id: }`), never HTML. The browser's
`change-feed` controller posts each fact to the page's live URL (`ChangeFeedRefresh`), where the
screen takes it as `live(message)` and answers with its own patches. A feature is a composition that
is itself a part: its inputs wrap their runs in `collect`, and an arm that says `out` makes a pair
one of the feature's outputs (`DESIGN.md`, "V07's design"). V08's one fold stays: the portal's volume
tier is the `VOLUME_TIER` lambda on the page.
