# V06 design: plain Rails

V03's design in plain Ruby. The layer map, the values that do no I/O, the stores as source-and-sink
abstractions, the Turbo Stream patches and the per-request screens are V03's (`../v03-pure-core-streams/DESIGN.md`).
This document records what V06 changes, why, what it costs, and the hand walk after the build.

## Why

Every Ruby variant before this one rated familiarity 4 or 3, and the reason was the same: the
`Foundation::Ports` vocabulary. `output`/`input` macros, `wire_to`/`on`, `emit`/`ask`, sinks built as
port objects. V50 reached familiarity 5 in Elixir by keeping state abstractions as functions that
return `{state, outputs}` and wiring with plain `wire/3` clauses. V06 is the Rails analogue.

## The shape

**A domain abstraction is a plain Ruby object.** An input is a public method. Its outputs are the
keys of the Hash it returns (or an Array of pairs when a name repeats). `OUTPUTS` lists them, as the
port declaration a reader and the coverage test can see:

```ruby
class CartLines
  OUTPUTS = %i[changed adding rows row_added row_changed row_removed contents removed saved line].freeze

  def bump(change)
    item = find(change[:item_id])
    item[:quantity] = [ item[:quantity] + change[:delta], 1 ].max
    { changed: { op: :quantity, id: item[:id], quantity: item[:quantity] }, row_changed: row(item), contents: contents }
  end
end
```

A store is the same with no outputs to speak of: `lookup` answers, `apply` returns nil. A sink
(`LiveUpdate`, `Patches`) is a plain object with a method.

**A screen wires with one `case`.** `ProgrammingParadigms::Wiring#run(part, outputs)` feeds every
pair a part returned to `wire(part, output, payload)`; the arms are the wiring, read top to bottom,
and an arm either runs another part or lands the payload on the page:

```ruby
in [ :lines, :changed ] then run(:items, @items.apply(payload))
in [ :lines, :rows ] then @rows = payload
in [ :lines, :row_changed ] then @patches.replace(@dom.cart_line_id(payload[:id]), @line_html.(payload))
```

Spray's composition "specifies a number of objects that must be instantiated, configured, and wired
together" (§3.11.3); here the instantiation is `initialize`, the configuration is the keyword
arguments, and the wiring is the table. Nothing else connects two parts.

**A pull is an argument.** Where V03 had a request/response port (`ask(:items)`), the composition
passes what the value needs: `run(:lines, @lines.load(@items.lookup))`, and the flows take the lines
when they start or pay: `run(:flow, @flow.pay(@lines.lines))`. The product lookup the three values
need mid-change is a configured lambda, `products: ->(ids) { products.lookup(ids) }`, which is
Spray's lambda-as-configuration (§3.11.3) and the form V02 already used for a row's links.
`SavedItems` gained `reload`, since a stash gives the new line its id in the store and the value
can no longer ask for it itself; the arm writes and reloads in one line.

**Grounded outputs are dropped, unlisted ones raise.** `run` skips an output the screen lists in
`GROUNDED`; any other output with no arm is a `NoMatchingPatternError`, which is the coverage test
at run time. The structural test, `Drawing.gaps`, reads the arms with Prism and compares them with
every part's `OUTPUTS`.

**The trace is thirteen lines.** Every output passes through `run`, so `Wiring` records the hop from
the output being routed (or `:outside`) to the part it reached, and a landing when an arm ran no
part. The suite turns the trace on and fails after a full run if a declared output was never
routed; its first run found the cart's `wishlist.dropped` untested (V05's trace found the same)
and two portal outputs that could never fire (`lines.adding`, `items.added`: the portal adds through
`AddLine`), now grounded with the reason. `docs/diagrams/running/` draws each screen from the hops;
`docs/diagrams/` from the arms.

## What it costs

- `OUTPUTS` is a declaration beside the methods, where V03's `output` macros were; a reader checks
  the two agree, and the structural test does when a screen wires an output nobody declares.
- Fan-out order is the order of statements in an arm, not of wires; an arm that does three things
  reads as three lines, and the linter reads them as wiring only inside the table (the one helper
  that pulled five patches out of an arm was its one finding, and went back in).
- An output that repeats in one call (`SettleOrder` announcing one stock change per product) is an
  Array of pairs rather than a Hash; the two shapes are a line in `Wiring`'s comment.
- The screen holds the configured `@dom`, `@t`, `@say`, `@urls` and `@line_html` as fields for the
  arms to read, since a `case` arm is not a closure over `initialize`'s locals as V03's blocks were.
- `products` as a lambda is one wire the drawing does not show.

## Checklist walk (Ruby edition, by hand)

After the build: 57 + 5 tests green, 0 declared outputs unrouted after the full suite, RuboCop clean,
`ala_lint` 100/100 at every tier with no finding and no accepted line. V03's walk holds; what V06
changes:

| Rule | Verdict | Evidence |
|---|---|---|
| R9 | met | one interface shape for every abstraction, "a method returns its outputs", which is the paradigm; no class owns a protocol another must learn |
| R11 | met | the screens' inputs are one `run` each; the arms run a part or land a value; the five summary patches live in their arm |
| R5 | met | the names an arm matches are the names a part's `OUTPUTS` declares, and the structural test holds the two together |
| R8 | met, better | the wiring reads as a table a Rails developer has seen in a service object; the drawing is the table, and the running drawing is the suite |
| R4 | met | a value holds its state; the screen holds what landed for the view, inside the table, as V03's blocks did |
| R6 | met | `run` and `wire` are two words; `OUTPUTS` is the third |
