# V07 under ala_lint_ruby

Run on 2026-10-17 with `../../ala_lint_ruby/bin/ala_lint --root .` and a six-layer map: V06's five
with `features` between application and domain.

| tier | score | rules met | functions clean |
|---|---|---|---|
| default | 100/100 (A) | 10 of 10 checked | 339/339 |
| `--strict` | 100/100 | 10 of 10 | 339/339 |
| `--super-strict` | 100/100 | 10 of 10 | 339/339 |

No line is accepted. Two linter changes, both precision rules with tests, and both leave V05 and
V06 at the same scores:

- `out` and `collect` joined `run` on the list of wiring calls, so a feature's `collect { run(...) }`
  and an arm's `out(name, payload)` are wiring, not handled data (R11).
- The public-surface count leaves out `parts` along with `initialize`: it is the paradigm's message,
  read by a drawing or a coverage test, not an input a page sends. With it, the feature's twelve
  inputs were counted as thirteen.

## 2026-10-19: the clone check

The linter's clone check found 9 duplicates across units (`--strict` and `--super-strict` 98). All
were extracted (README, "Since 2026-10-19"); three lines are accepted by hand:

| tier | score | rules met | functions clean |
|---|---|---|---|
| default | 100/100 (A) | 10 of 10 checked | 370/370 |
| `--strict` | 100/100 | 10 of 10 | 370/370 |
| `--super-strict` | 100/100 | 10 of 10 | 370/370 |

- `CartLines#initialize`, clone of `SavedItems#initialize`, and `CheckoutFlow#initialize`, clone of
  `SubmitOrder#initialize`: each builds the extracted abstraction from the same config as its twin.
- `CheckoutFlow#show`, passthrough: delegation to `StepRecord` in place of inheriting it (§7.16).

Later the same day the pages took over building `HeldProducts` and `StepRecord` and hand them in
(`held:`, `steps:`), as V05 and V06 do; the two constructor clones went with it and their accepts
were removed. Still 100/100 and 10 of 10 at every tier, 370/370 functions, the same six advisory
lines, and one accepted line: `CheckoutFlow#show`, still a delegation the linter can't tell from
proliferation.

The `clone_inside` findings (in `CartLines` and `Drawing`) are reported and unscored by design.

## 2026-10-21: the ChangeFeed paradigm and step tables

The linter's new R11 check (a template chosen by a name built at run time) found two lines,
`render "checkouts/#{@s.step}"` and `render "portals/#{@s.step}"` (99, 368/370). Each now reads a
literal `STEP_VIEWS` table on its screen. Moving the live paths onto `ProgrammingParadigms::ChangeFeed`
first drew two R11 findings of its own: the row lambdas looped (`sum`) over a lookup. That is a
loop in the composition, and the fix lets the framework iterate instead (`Partial.each`, a
collection render).

| tier | score | rules met | functions clean |
|---|---|---|---|
| default | 100/100 (A) | 10 of 10 checked | 384/384 |
| `--strict` | 100/100 | 10 of 10 | 384/384 |
| `--super-strict` | 100/100 | 10 of 10 | 384/384 |

Same accepted line (`CheckoutFlow#show`), no new ones; the advisories are the same less `r11_share`.
