# V05 under ala_lint_ruby

Run on 2026-10-10 with `../../ala_lint_ruby/bin/ala_lint --root .` and a six-layer map: V02's five with `features` between application and domain.

| tier | score | rules met | functions clean |
|---|---|---|---|
| default | 100/100 (A) | 10 of 10 checked | all |
| `--strict` | 100/100 | 10 of 10 | all |
| `--super-strict` | 100/100 | 10 of 10 | all |

Nine lines are accepted (`--list-accepted` prints them with the finding each covers; none is stale):

- `app/ala/programming_paradigms/long_lived.rb`, R2: the class-level table of registries by name. A job
  reaches a kept composition by naming its registry; the table is process-wide by nature, and the
  execution model is where that lives.
- `app/models/{checkout,order}.rb`, R1: the same write stamp as the line models, added when the
  checkout became long-lived.


- `app/ala/programming_paradigms/long_lived.rb`, two lines, R4: the execution model makes a `Mutex`
  for its table and one per kept composition. The check is right that a lock in a domain class is a
  smell; this class is the arbitrator the check points at, so the lock is decided here.
- `app/models/{cart_item,saved_item,wishlist_item,cart_pricing_choice}.rb`, R1: an `after_commit`
  that bumps the cart's version. The check flags a model callback reaching another model as a lower
  record deciding what happens next. Here nothing happens next: the stamp is the store's own, read
  by whoever wants to know whether the cart changed.

Findings fixed when the running trace and the kept checkout were added (2026-10-11):

- `PushLater#perform` read `Rails.configuration.x` to find the registry (R9, an endpoint). The registries
  are now named on `LongLived` itself.
- Two `if`s inside the checkout controller's `with_screen` blocks (R11, logic in a wiring block). They
  are the controller's redirect-or-render choice and moved to private methods.
- Not a linter finding, but the trace's: three wires in the checkout that could never fire. Removed.

Findings fixed during V05's build:

- `Drawing` asked a part `respond_to?(:parts)` to decide whether to walk into it (R9: duck typing to a
  peer's own message). Every ported object now answers `parts` (empty for a leaf), a Foundation message.

Findings fixed during V04's build, both real:

- `LongLived#initialize` defaulted `capacity: 1000` (R3): a product decision in a paradigm class. It
  is now configured in `config/initializers/compositions.rb`.
- The three values' header comments did not list their new `show` port (the ports check).

Not read by the linter: whether the stamp covers every write (a raw `update_all` bypasses the
callback; the long-lived cart test shows that half too), and whether rendering inside the
composition's turn holds the lock longer than a deployment wants.
