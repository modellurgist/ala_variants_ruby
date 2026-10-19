# Screens::Catalog, as it ran

```mermaid
flowchart LR
  screen[[Screens::Catalog]]
  records[records: Records]
  add_line[add_line: AddLine]
  records -- rows --> screen
  records -- record --> screen
  records -- form --> screen
  records -- created --> screen
  records -- updated --> screen
  records -- deleted --> screen
  records -- created → push --> liveupdate_42480([LiveUpdate])
  records -- updated → push --> liveupdate_42488([LiveUpdate])
  records -- deleted → push --> liveupdate_42496([LiveUpdate])
  add_line -- added --> screen
```
