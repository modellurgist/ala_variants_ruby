# V07: Plain Features

V06 (`../v06-plain-rails`) with Spray's Features layer (§2.2) in the same plain Ruby, and one feature
in it placed by two pages. `Features::OrderLines` is a class with the `wire` a screen has: inside, a
`CartLines` value and an `Undo` are wired to each other; an arm that says `out(name, payload)` makes
that pair one of the feature's own outputs, and each input wraps its runs in `collect` and returns
them. The page runs the feature exactly as it runs a part, `run(:order, @order.bump(change))`, and
wires what comes back to its store, its totals and its patches. The cart page places it with the
storefront's links and a five-second undo window; the portal with its own links and ten seconds.
The drawing opens the feature as a subgraph with its arms inside, and the trace records its inner
hops under the feature's name. `DESIGN.md` has the shape and the hand walk.

What V07 leaves out on purpose: V04's kept compositions, the stamp column and the job delivering
into a kept checkout. Those are the things that cost V04 and V05 a familiarity point, and they do
not depend on the Features layer; V05 keeps them and stays the fullest expression of ALA in Ruby.
V07 is the leading edge at familiarity 4.

**Status:** 86 integration and unit tests (V06's 57, 3 of the feature, 3 for later fixes, 23 for the
abstractions the clone check extracted) and 7 Cuprite browser tests, 0 failures; after the full suite, **0 declared outputs never routed**, the
feature's inner outputs included; RuboCop clean; `../../ala_lint_ruby/bin/ala_lint --root . --super-strict` scores it
**100/100 at every tier with no scored finding** (370 functions; one accepted line, below, and one
inherent declaration, the drawing's edge labels). Until the linter's Prism fix of 2026-10-19 it skipped
`programming_paradigms/drawing.rb` and `wiring.rb`; checking them found three R9 findings
(`respond_to?(:parts)`, now `is_a?(Wiring)`) and two R3 (the drawing's notation, now
`INHERENT_LABELS`). The linter
learned that `out` and `collect` are wiring calls and that `parts` is the paradigm's message, not
an input (since 2026-10-19 `Wiring` declares `parts` itself, and the linter reads paradigm messages
from the paradigm's code rather than a list); `LINT_NOTES.md` has the run. Familiarity 4 of 5 (judgement): V06 plus one more word.

*Since 2026-10-19:* the linter's clone check (duplicated logic, R7, scored from `--strict`) found 9
duplicates, which put `--strict` and `--super-strict` at 98. Each was one concept written twice, and
each now has one home a layer down: `Rules::LineRequest` (what an add request means, for `AddLine`
and `CartLines#receive`), `CartItem#to_line` (the stored line's shape, for the store and `Undo`),
`Rules::Pricing.summary` (subtotal, discount, shipping on the subtotal, total, for both totals),
`Rules::HeldProducts` (entries naming products, their catalog and their row, for `CartLines`,
`SavedItems` and `Wishlist`), and `ProgrammingParadigms::StepRecord` (a `Transitions` machine kept in
a record that is also the form, for `CheckoutFlow` and `SubmitOrder`). The pages build
`HeldProducts` and `StepRecord` with their configuration and hand them in (`held:`, `steps:`; the
feature hands its page's `held:` on to its `CartLines`), as V05 and V06 do, so no constructor
repeats another. One line is accepted with
`ala:accept`: `CheckoutFlow#show`, delegation to `StepRecord` in place of inheritance (§7.16).
`ala_lint --list-accepted` prints it. `test/ala/shared_concepts_test.rb` tests each extracted
abstraction in its own home.

## Run it

```bash
cd v07-plain-features         # asdf picks Ruby 4.0.7 from .ruby-version
bin/rails db:prepare db:seed  # Postgres at localhost, user postgres/postgres (see config/database.yml)
bin/dev                       # http://localhost:3000
bin/rails test                # fails if a declared output never routed
bin/rails ala:diagrams        # docs/diagrams/*.md from the wire arms, features opened
```

## What's where

As V06, plus:

| Layer | Directory | Holds |
|---|---|---|
| Features | `app/ala/features/` | `OrderLines`: `CartLines` and `Undo` wired inside, `out` for what leaves, placed by the cart page and the portal page |
| Rules | `app/ala/rules/` | adds `HeldProducts` and `LineRequest`, and `Pricing.summary` |
| Programming paradigms | `app/ala/programming_paradigms/` | adds `StepRecord` |

## How a feature runs

```ruby
class Features::OrderLines
  include ProgrammingParadigms::Wiring
  OUTPUTS = %i[changed adding rows row_added row_changed row_removed contents saved line undo_pending restored].freeze
  GROUNDED = [].freeze

  def parts = { lines: @lines, undo: @undo }
  def bump(change) = collect { run(:lines, @lines.bump(change)) }
  def undo = collect { run(:undo, @undo.restore) }

  private

  def wire(part, output, payload)
    case [ part, output ]
    in [ :lines, :removed ] then run(:undo, @undo.capture(payload))   # wired inside
    in [ :undo, :restored ] then run(:lines, @lines.arrived(payload)); out(:restored, payload[:id])
    in [ :undo, :pending ] then out(:undo_pending, payload)            # leaves, renamed
    in [ :lines, _ ] | [ :undo, _ ] then out(output, payload)           # leaves as it is
    end
  end
end
```

`collect` opens a buffer, `out` appends to it, and the input returns it, so to the page the feature
is a part whose method returned its outputs. See `DESIGN.md`.
