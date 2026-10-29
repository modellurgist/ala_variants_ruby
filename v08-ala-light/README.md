# V08: ALA Light

V07 (`../v07-plain-features`) under the relaxed rule set "ALA Light, subset 2"
(`../../ala_lab/docs/Q-ala-light-subsets.md`): layers and a composition page, with logic allowed on
the page as pure functions. The change sequence of 2026-10-21 put ALA's cost per change largely on
R11 applied as a hard gate and on the function limit, and its benefit on layering (R1, R3) and the
composition reading as the requirements (R8). V08 keeps the second and loosens the first, on
Spray's own basis: an application-specific function kept in the application layer because "all the
code in the application is specific to the application requirements" (§6.28.1, §6.28.3).

R11 is relaxed to advice, not a score. An application-specific pure function may be written
on a page or in a feature and handed to an instance as configuration or called from a wire arm; a
branch or loop that would otherwise become a one-use abstraction may stay on the page, and R7
(earns its existence) decides. The public surface is reported only, and R10 reads lifecycle by
identity key as the identity's business. The rest is not relaxed. The wiring reads top to bottom
(R8), literals live at the composition (R3), a domain part never knows one page's words (R3, R6),
and the page still does not compute between wire arms with assignments. Ports, features as compositions,
the running trace, the "every declared output is routed" test and the drawings all stay.

One fold changed the code. `Rules::VolumeTier` was used by the portal page alone, so it is
now `Screens::Portal::VOLUME_TIER`, a lambda beside the page's other configuration, handed to
`OrderTotals` as `volume:` exactly as the class was (`OrderTotals` calls `volume.call`, so nothing
below the page changed but its header comment). Its unit cases moved to
`test/controllers/portal_test.rb`. No other rule is folded: each of the rest is used by two or more
compositions or by a domain part directly. `.ala_lint.rb` gains `checks: { r11: :advisory }`.

**Status:** 101 integration and unit tests (V07's 100, with the volume-tier cases moved from the
domain test to the portal's) and 9 Cuprite browser tests, 0 failures; after the full suite, **0
declared outputs never routed**; RuboCop clean (116 files, no offenses);
`../../ala_lint_ruby/bin/ala_lint --root . --super-strict`, `--strict` and default all score
**100/100 with no scored finding**, 10 of 10 rules met, 382 functions (V07's 384 less the folded
rule's two). R11 is advisory at every tier and reports exactly the fold: `Screens::Portal::VOLUME_TIER`
branches and iterates in a lambda the constant holds (the linter learned to walk a constant's lambda
on 2026-10-21; before that the fold was invisible to it). The rest of the advisory
list is V07's (`app_share` 36%, four `clone_inside`, `module_avg`). Familiarity: V07's 4 of 5.

## Inherited from V07

*Later (2026-10-21):* outside change is a paradigm, `ProgrammingParadigms::ChangeFeed` (the checklist's
"A live subscription port"). A composition that changes something wires the output to a
`ChangeFeed::Publish` sink configured with a topic and a kind; a page places a `ChangeFeed::Subscription` configured with
its topic and the kinds it listens to, and wires each kind as an output (`feed.stock`). What travels
is a fact keyed by identity (`{ product_id:, stock: }`, `{ cart_id: }`), never HTML. Delivery is
built once: the browser's `change-feed` controller subscribes through `ChangeFeed::Channel` and posts each fact to
the page's live URL (`ChangeFeedRefresh`, one concern on four controllers), where the screen takes it as
`live(message)` and answers with its own patches. `LiveUpdate`, which rendered another page's HTML in
the composition making the change, is gone, and so are the pages' `turbo_stream_from` tags. Two gaps
closed on the way: a staff edit at /products now publishes the product's stock, so it reaches open
carts and the portal (before, only a purchase did), and the portal renders its own catalogue row
for a product change. Before, it received the product list's row with the same DOM id, edit and
delete buttons included. The two step templates that were chosen by an interpolated name
(`render "portals/#{@s.step}"`) now read a literal `STEP_VIEWS` table (R11). 100 integration and
unit tests and 9 browser tests, 0 outputs unrouted, RuboCop clean, `ala_lint` 100 at every tier
with 10 of 10 rules (384 functions), no new accepted line.

## Run it

```bash
cd v08-ala-light              # asdf picks Ruby 4.0.7 from .ruby-version
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
| Programming paradigms | `app/ala/programming_paradigms/` | adds `StepRecord`, and `ChangeFeed` (publish sink, feed, channel) in place of `LiveUpdate` |

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
