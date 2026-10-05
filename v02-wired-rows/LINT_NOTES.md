# V02 under ala_lint_ruby

Run on 2026-10-05 with `../../ala_lint_ruby/bin/ala_lint --root .` and the five-layer map in
`.ala_lint.rb`.

| tier | score | rules met | functions clean |
|---|---|---|---|
| default | 100/100 (A) | 10 of 10 checked | 204/204 |
| `--strict` | 100/100 | 10 of 10 | 204/204 |
| `--super-strict` | 100/100 | 10 of 10 | 204/204 |

No scored finding at any tier; no advisory the tiers promote. Two report-only measures remain, and
should: **app_share** (42%: controllers' actions and page templates are counted as composition
functions, and a request-per-action framework has many) and **module_avg** (18 lines: the rules
and the one-port domain classes are deliberately small).

## What V01's findings became

| V01 finding | V02 |
|---|---|
| components rendering peer components, calling a peer helper (8 × R1) | `views/elements/` under `views/components/`; `Foundation::DomTargets` declared with `helper`; no component renders a component |
| stateful domain abstractions calling pure rules (7 × R1) | `Rules::` layer under the domain |
| `LiveUpdate`/`PushLater` naming the paradigm layer and `ApplicationController` (3 × R1) | both in `programming_paradigms/`; rendering through `Screens::Partial` |
| `belongs_to :product` on three line tables (3 × R10) | associations gone; a `products` pull port per feature wired to one `ProductIndex` |
| `"checkout_status"`, `"modal"` agreed between a screen or page and a component (2 × R5) | `Screens::Checkout::STATUS_TARGET`, `Screens::Catalog::MODAL_FRAME`, passed as locals |
| `SecureRandom.hex(6)` (R3) | `SecureRandom.hex` |
| input ports missing from headers (11 × ports) | every header lists ports in and out |
| `Undo.expired`, `SettleOrder.settled` wired by nobody (ports_unwired) | removed |
| branches in `Catalog`'s wiring blocks, `PortalsController#submit`, the session fallbacks; loops, a comparison and `persisted?` ternaries in page templates (15 × R11) | `Records` emits `created`/`updated`/`record`; `SubmitOrder` emits its step on a failed submit; `session.fetch` with a default; `render collection:` with rows carrying URLs; the cart line takes the wishlist's ids; `form_with model:`; the controller hands the page its title |

## Where the map makes a call the linter can't

- **`rules` and `elements` as a layer.** The drop from `CartTotals` to `Rules::Pricing`, and from
  `cart_line` to `product_line`, is real: the lower side takes any input and knows no store. But
  it is a declaration; a map with one domain layer would report the same code as fifteen peer
  edges. The honesty is in the names: nothing in `rules/` or `elements/` reads a store or a word.
- **`peer_ok` on the paradigms layer.** `LiveUpdate` and `PushLater` build `DataFlow` ports: an
  execution model knowing the interface it runs, which Spray keeps in one layer ("Execution
  models.doc" sits in Programming Paradigms). Declared, not inferred.
- **`session.fetch(:cart_id) { cart_id }`.** The fallback is now the session's default rather than
  an `||`. Same behaviour; the guard lives in the connection mechanism, which is the checklist's
  first move for a propagation guard. A reader may still call it a branch.
- **Controllers' outcome routing.** `saved_or_form` and the checkout's address action branch on
  `screen.saved` / `screen.step` with arms that only redirect, render, or hand the page a value.
  The linter exempts that as routing (R11's own exemption); it stays a form a stricter reader might
  move into two outputs the controller wires to two responses.
- **A partial name as a port.** `product_row` renders its actions when given words for them; no
  component takes a partial name. Had one, the linter would not see it as an edge.

## Not read by the linter

JavaScript (the five Stimulus controllers and the `data-controller`/`data-action` names the
templates use), the migrations, and the routes' correspondence to the URLs rows carry. The
integration tests cover the last.
