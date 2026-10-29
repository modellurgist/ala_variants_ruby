# V06 under ala_lint_ruby

Run on 2026-10-12 with `../../ala_lint_ruby/bin/ala_lint --root .` and V02's five-layer map.

| tier | score | rules met | functions clean |
|---|---|---|---|
| default | 100/100 (A) | 10 of 10 checked | 324/324 |
| `--strict` | 100/100 | 10 of 10 | 324/324 |
| `--super-strict` | 100/100 | 10 of 10 | 324/324 |

No line was accepted then; the clone check added on 2026-10-19 led to two (the README's status). The linter needed to learn two shapes, the way the Elixir linter learned two to
read V51, and both are precision rules rather than exemptions:

- **A wiring table.** A `case [part, output]` in a method named `wire`, whose arms all match two
  symbols, is the composition's wiring, not a branch (R11). Its arms run after the input that caused
  them, so a field landed inside one is a landing (R4), as a field landed inside a `wire_to` block was.
  A `case` in any other method, or with any other pattern, is still a branch.
- **`run` is a wiring call.** A part's call fed to `run`, including a pull passed straight in
  (`@lines.load(@items.lookup)`), is a wire, not handled data (R11). The same pull outside `run`
  (`@lines.load(@items.lookup)` in an ordinary method) is still flagged.

Before the second rule, the linter's one real finding was a helper that pulled five patches out of
the `totals.summary` arm: ten handled-data findings, all right. The patches went back into the arm.

One thing to know: while the parser was half-changed the linter skipped the screens with a warning
and scored the variant 100. A skipped file is a warning on stderr, not a finding; read the warnings.

Later (2026-10-21): the linter learned that a template picked by a name built at run time is a branch,
and found two (`render "checkouts/#{@s.step}"`, `render "portals/#{@s.step}"`), 99 at every tier. Both
now render from a literal `STEP_VIEWS` table on their screen, and it is 100 again. A `case` in the
template whose arms only render, the other form the finding's message suggests, is still flagged
there: the template check counts every branch and has no routing exemption.
