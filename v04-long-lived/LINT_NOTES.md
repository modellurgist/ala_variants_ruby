# V04 under ala_lint_ruby

Run on 2026-10-10 with `../../ala_lint_ruby/bin/ala_lint --root .` and V02's five-layer map.

| tier | score | rules met | functions clean |
|---|---|---|---|
| default | 100/100 (A) | 10 of 10 checked | all |
| `--strict` | 100/100 | 10 of 10 | all |
| `--super-strict` | 100/100 | 10 of 10 | all |

Six lines are accepted (`--list-accepted` prints them with the finding each covers; none is stale):

- `app/ala/programming_paradigms/long_lived.rb`, two lines, R4: the execution model makes a `Mutex`
  for its table and one per kept composition. The check is right that a lock in a domain class is a
  smell; this class is the arbitrator the check points at, so the lock is decided here.
- `app/models/{cart_item,saved_item,wishlist_item,cart_pricing_choice}.rb`, R1: an `after_commit`
  that bumps the cart's version. The check flags a model callback reaching another model as a lower
  record deciding what happens next. Here nothing happens next: the stamp is the store's own, read
  by whoever wants to know whether the cart changed.

Findings fixed during the build, both real:

- `LongLived#initialize` defaulted `capacity: 1000` (R3): a product decision in a paradigm class. It
  is now configured in `config/initializers/compositions.rb`.
- The three values' header comments did not list their new `show` port (the ports check).

Not read by the linter: whether the stamp covers every write (a raw `update_all` bypasses the
callback; the long-lived cart test shows that half too), and whether rendering inside the
composition's turn holds the lock longer than a deployment wants.
