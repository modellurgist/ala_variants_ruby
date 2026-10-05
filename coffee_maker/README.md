# coffee_maker

Spray's coffee maker (site §2.9) in Ruby, as his diagram: instances of three domain abstractions,
the logic abstractions the diagram is drawn with (an AND gate, NOT, equality, rising edges), and a
state machine, wired port to port in one application class. Plain Ruby, no gems; the Foundation
(`Ports`) and the paradigms are the ones the Rails variants use.

```bash
ruby -Ilib test/coffee_maker_test.rb   # 11 tests: Martin's scenarios as readings in, commands out
bin/run                                # brews a pot in the simulator, one line per cycle
bin/run draw                           # the wiring as Mermaid (also in docs/diagram.md)
../../ala_lint_ruby/bin/ala_lint --root . --super-strict   # 100/100
```

## Layout

- `lib/coffee_maker.rb`: `CoffeeMaker`, the application: the only file with the word "coffee"; its constructor is the diagram.
- `lib/coffee_maker/domain_abstractions/`: `Boiler`, `WarmerPlate`, `UserInterface`, and `logic.rb` (`Gate`, `Not`, `Equals`, `RisingEdge`).
- `lib/coffee_maker/programming_paradigms/`: `DataFlow`, `Event`, `StateMachine`, `Drawing`.
- `lib/coffee_maker/foundation/`: `Ports`, `SensorReading` and `HardwareCommand` (the hardware boundary as data), `SimulatedHardware`.

Two Ruby details worth knowing: an output port is the instance variable of its name, so a class
can't also keep state under that name (`Boiler` keeps `@dry` and sends on `empty`); and inputs the
application pushes in the same cycle see each other's outputs in wiring order, so the boiler and the
plate are sensed before the button, as Spray's `Poll` reads all three before the lines run.
