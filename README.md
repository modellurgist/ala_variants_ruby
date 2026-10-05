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
