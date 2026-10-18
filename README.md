# ala_variants_ruby

Worked Ruby on Rails designs that the Ruby and Rails edition of the **ALA Checklist**
(`../ala_checklist/ala_checklist_ruby.md`) is applied to, built from the same functional
requirements as the Elixir variants (`../ala_lab/docs/requirements-storefront-and-portal.md`).

> Independent, unofficial examples applying John Spray's
> [Abstraction Layered Architecture](https://www.abstractionlayeredarchitecture.com/).
> Not affiliated with or endorsed by the author.

Each `v*` directory is a self-contained Rails app with its own `.ruby-version` (asdf) and database
names, so `cd` into one and run it.

| Directory | What it shows |
|---|---|
| `v01-wired-screens/` | Rails 8.1 + Hotwire; one per-request screen composition per page, wiring domain abstractions port to port with a 90-line `Foundation::Ports`; feature tables keyed by cart id; Turbo Stream broadcasts and an Active Job wired as ports; 48 tests |
| `thermometer/` | Spray's thermometer at §1.6.6 in plain Ruby: a dataflow chain of configured instances, a display inside a window, a tick; 100/100 at `--super-strict` |
| `coffee_maker/` | Spray's coffee maker (§2.9) in plain Ruby as his diagram: three domain abstractions, logic gates and a state machine wired in one application class; Martin's scenarios as tests; 100/100 |
| `v07-plain-features/` | V06 with Spray's Features layer in the same plain Ruby: a feature is a class with the `wire` a screen has, `collect` and `out` make its parts' outputs its own, and `Features::OrderLines` is placed by the cart and the portal with their own links and undo windows; drawings open a feature; 100/100 at `--super-strict` with no finding, 60 + 5 tests, familiarity 4 |
| `v06-plain-rails/` | V03 in plain Ruby: no port macros or objects; an input is a method, its outputs are the Hash it returns, a screen wires with one `case [part, output]`, a pull is an argument; a thirteen-line trace fails the suite on an output never routed; 100/100 at `--super-strict` with no finding, 57 + 5 tests, familiarity 5 |
| `v03-pure-core-streams/` | V02 with two Elixir techniques: the cart's lists are values that pull through ports and write through wired stores (the domain tests run without Postgres), and a change on the cart answers a Turbo request with the patches its outputs made instead of a redirect; 100/100 at `--super-strict`, 57 + 5 tests |
| `v04-long-lived/` | V03 with the cart's composition built once per cart and kept: `ProgrammingParadigms::LongLived` runs each request under the composition's own lock (the arbitrator, decided at wiring time), reloads the values when the cart's write stamp moved, and clears flash and patches per request; 100/100 at `--super-strict` with six accepted lines, 66 + 5 tests |
| `v05-shared-feature/` | V04 with Spray's Features layer: `Features::OrderLines` (a `CartLines` and an `Undo` wired inside, `forward`ed outside) placed by the cart page inside its long-lived composition and by the portal page per request; a running trace the suite turns on, so every wire must carry something under the full run and `docs/diagrams/running/` draws what did; the checkout kept too, with the job delivering into it; 100/100 at `--super-strict`, 70 + 5 tests |
| `v02-wired-rows/` | V01 iterated until `ala_lint_ruby` scores it 100/100 at `--super-strict`: a declared five-layer map (rules and UI elements under the domain), product data through a pull port instead of an association, rows carrying their own URLs so pages render collections, names flowing down; 48 tests |

Lint a variant with `../ala_lint_ruby/bin/ala_lint --root v01-wired-screens` (settings in its
`.ala_lint.rb`); each variant's `LINT_NOTES.md` reads the findings.

Run a variant:

```bash
cd v01-wired-screens
bin/rails db:prepare db:seed
bin/dev
bin/rails test
```
