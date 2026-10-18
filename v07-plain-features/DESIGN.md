# V07 design: a feature in plain Ruby

V06's design (`../v06-plain-rails/DESIGN.md`) with Spray's Features layer added in V06's own
vocabulary, and one feature in it placed by two pages. This document records what V07 adds, why,
what it costs, and the hand walk after the build.

## Why

V05 built a feature placed by two pages over the Ports foundation, with `forward` lines to make its
parts' outputs its own, and rated familiarity 3 with V04's kept compositions underneath. V06 dropped
the foundation and reached 5. The question V07 answers is whether the Features layer can be added
to V06's shape without losing more than one point.

## The shape

**A feature is a composition that is itself a part.** It includes the same `Wiring` a screen does,
names its parts, and wires them in its own `wire`. What V06 lacked was a way for a composition's
arms to say "this leaves me": a screen lands an output on itself, but a feature has a page above
it that wants the output back. Two words in `Wiring` do it:

```ruby
def collect
  saved, @out = @out, []
  yield
  @out
ensure
  @out = saved
end

def out(output, payload) = (@out << [ output, payload ]; nil)
```

A feature's input wraps its runs in `collect` and returns the buffer; an arm that says `out`
appends to it. The page runs the feature as it runs a part, and the pairs that come back are the
feature's outputs. Spray's feature "creates instances of domain abstractions, configures the
instances with feature specific details, and connects them together", and "features can also have
ports and be wired together" (§2.2): the instances are `initialize`, the connections are the arms
that `run`, and the ports are `OUTPUTS` and the arms that `out`.

**One arm for everything that leaves.** `in [ :lines, _ ] | [ :undo, _ ] then out(output, payload)`
says that every output of the two parts not wired inside leaves under its own name. The `_`
pattern is read by the structural test as "every remaining declared output of that part", so the
coverage check still holds per output, and the drawing shows it as one edge labelled "every other
output".

**Two pages place it.** The cart with the storefront's links and a five-second window; the portal
with its own links and ten seconds. The portal grounds the outputs its rows never offer (`saved`,
`line`, the row deltas) in its `GROUNDED`, as V06 already did for the bare value. Neither page's
other arms changed except that `lines` and `undo` became `order`.

**The drawing opens the feature.** `Drawing` takes a built screen now (it needs the parts' classes
to know which are compositions), draws a feature as a subgraph with its inner arms, and sends an
`out` arm's edge to the feature node. `gaps` and `unrouted` walk into features, so the structural
and the running coverage checks cover a feature's inside as well as the page.

## What it costs

- Two more words in `Wiring`, `collect` and `out`, for 14 lines; `Wiring` is 50 lines in all.
- A feature's inputs are one line each, twelve of them, which is the feature's whole interface
  restated once. V05's `forward` did the same for outputs; here outputs cost one arm.
- The linter counted `parts` as a thirteenth public method. It is the paradigm's message, what a
  drawing or a coverage test reads, so the count now leaves it out along with `initialize`.
- The trace records a feature's inner hops under the feature's class, so a feature placed by two
  pages has one running picture for both; the structural drawing is per page.
- No kept compositions: a feature here is rebuilt per request with its page, as V06's parts are.

## Checklist walk (Ruby edition, by hand)

After the build: 60 + 5 tests green, 0 declared outputs unrouted after the full suite (the
feature's inside included), RuboCop clean, `ala_lint` 100/100 at every tier with no finding and no
accepted line. V06's walk holds; what V07 adds:

| Rule | Verdict | Evidence |
|---|---|---|
| R1 | met | the feature depends on two domain abstractions and the paradigm; two pages depend on it; nothing in the domain knows it |
| R9 | met | the feature's interface is the same shape as a part's: methods in, returned pairs out; `collect` and `out` are the paradigm's words, not the feature's |
| R3 | met | links, window and the undo store are configuration; the portal's longer window is a `Store` constant with its reason |
| R6 | met | `out` is the one word for "this leaves me"; the feature's header lists every input and output |
| R8 | met, better | a page's wiring reads "place the order lines, give them a store, totals and patches"; the drawing opens the feature and the suite proves its inside ran |
