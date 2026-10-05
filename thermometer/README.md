# thermometer

Spray's thermometer at its last rung (site §1.6.5–1.6.6) in Ruby: instances configured by the
application, a dataflow chain from an ADC to a display, the display inside a window through a
UI-layout port, and a tick event that drives it. Plain Ruby, no gems; the Foundation (`Ports`) and
the paradigms are the ones the Rails variants use.

```bash
ruby -Ilib test/thermometer_test.rb   # 4 tests
bin/run                               # 60 readings of a warming sensor, the window every tenth
bin/run draw                          # the wiring as Mermaid (also in docs/diagram.md)
../../ala_lint_ruby/bin/ala_lint --root . --super-strict   # 100/100
```

## Layout

- `lib/thermometer.rb`: `Thermometer`, the application; every number and word is here.
- `lib/thermometer/domain_abstractions/pipeline.rb`: `Reader`, `OffsetAndScale`, `LowPassFilter`, `SampleEvery`, `Display`, `Window`.
- `lib/thermometer/programming_paradigms/`: `DataFlow`, `Event`, `UiLayout`, `Drawing`.
- `lib/thermometer/foundation/`: `Ports`, `Adc`.
