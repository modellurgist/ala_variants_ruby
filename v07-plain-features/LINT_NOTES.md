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
