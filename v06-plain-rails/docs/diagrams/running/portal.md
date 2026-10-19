# Screens::Portal, as it ran

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
  outside -- request --> undo
  undo -- pending --> screen
  outside -- request --> lines
  lines -- rows --> screen
  lines -- contents --> totals
  totals -- summary --> screen
  outside -- request --> catalog
  catalog -- rows --> screen
  outside -- request --> flow
  flow -- step --> screen
  flow -- form --> screen
  outside -- request --> add_line
  add_line -- added --> screen
  flow -- reference --> screen
  flow -- blocked --> screen
  lines -- changed --> items
  lines -- removed --> undo
  undo -- restored --> screen
```
