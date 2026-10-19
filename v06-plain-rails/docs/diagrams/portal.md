# Screens::Portal

```mermaid
flowchart LR
  screen[[Screens::Portal]]
  lines[lines]
  items[items]
  totals[totals]
  undo[undo]
  catalog[catalog]
  add_line[add_line]
  flow[flow]
  lines -- changed --> items
  lines -- rows --> screen
  lines -- contents --> totals
  lines -- removed --> undo
  undo -- pending --> screen
  undo -- restored --> screen
  catalog -- rows --> screen
  add_line -- added --> screen
  totals -- summary --> screen
  flow -- step --> screen
  flow -- form --> screen
  flow -- blocked --> screen
  flow -- reference --> screen
```
