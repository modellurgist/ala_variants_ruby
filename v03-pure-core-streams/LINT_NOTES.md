# V03 under ala_lint_ruby

Run on 2026-10-10 with `../../ala_lint_ruby/bin/ala_lint --root .` and V02's five-layer map.

| tier | score | rules met | functions clean |
|---|---|---|---|
| default | 100/100 (A) | 10 of 10 checked | 238/238 |
| `--strict` | 100/100 | 10 of 10 | 238/238 |
| `--super-strict` | 100/100 | 10 of 10 | 238/238 |

Two findings came up during the build and were real:

- `_saved_pane` and `_wishlist_pane` rendered `_saved_line` and `_wishlist_line`: a component rendering a
  peer (R1). The fix is V02's own: the pane is an element that takes the item partial's name from the page
  (`item: "components/saved_line"`), a UI-layout port bound by the composition.
- `"flash"` appeared in `DomTargets` and in the flash element (R5); the element now renders `flash_id`.

One linter change was needed, and it is a precision fix rather than an exemption: a no-argument read
of a name on a constant or a local (`dom.summary_id`, `Store::RATES`) passed into a call is
configuration being passed, not one abstraction's result handed to another, so R11's handled-data check
no longer counts it (a read on an instance variable still counts). The Ruby linter's suite has the case.

Not read by the linter: the Stimulus controllers, and whether every `DomTargets` id the screen patches is
rendered by the page (the stream tests cover the cart's).
