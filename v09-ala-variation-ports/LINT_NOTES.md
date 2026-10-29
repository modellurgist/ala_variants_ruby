# V09 under ala_lint_ruby

Run on 2026-10-22 with `../../ala_lint_ruby/bin/ala_lint --root .` and V08's settings (`.ala_lint.rb`:
six layers, `checks: { r11: :advisory }`, unchanged).

| tier | score | rules met | functions clean |
|---|---|---|---|
| default | 100/100 (A) | 10 of 10 checked | 377/377 |
| `--strict` | 100/100 | 10 of 10 | 377/377 |
| `--super-strict` | 100/100 | 10 of 10 | 377/377 |

No line is accepted. V08's one accept (`CheckoutFlow#show`, a delegation to `StepRecord`) went with
the method when the page started calling its `StepRecord` itself. No check was made advisory for V09.

While the code was being reshaped, calling the checkout's flow raised two scored `passthrough`
findings (`Screens::Checkout#validate` and `#submit_address` "delegates to @flow... unchanged"). They
were fixed in the code, not in the settings: `DESIGN.md`, "Lint: what the new shape tripped".

Advisory and reported (not scored): R11 21 findings (V08: 2), all on the cart, checkout and portal
pages: branches on what a called part answered, a store read handed to a held list, one `.each`.
`r11_share` is 7%, `app_share` 40%. `clone_inside` has V08's four plus `Cart#saved_changed` and
`Cart#wishlist_changed`. `module_avg` is unchanged in kind.

The history before V09 (V07's runs, the clone check of 2026-10-19, the ChangeFeed of 2026-10-21) is
in `../v07-plain-features/LINT_NOTES.md`.
