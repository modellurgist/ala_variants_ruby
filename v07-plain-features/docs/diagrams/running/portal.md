# Screens::Portal, as it ran

```mermaid
flowchart LR
  screen[[Screens::Portal]]
  subgraph order [order: OrderLines]
  order_lines[lines]
  order_undo[undo]
  end
  catalog[catalog]
  add_line[add_line]
  totals[totals]
  flow[flow]
  items[items]
  outside -- request --> order
  order -- undo_pending --> screen
  order -- rows --> screen
  order -- contents --> totals
  totals -- summary --> screen
  outside -- request --> catalog
  catalog -- rows --> screen
  outside -- request --> flow
  flow -- step --> screen
  flow -- form --> screen
  flow -- blocked --> screen
  outside -- request --> add_line
  add_line -- added --> screen
  order -- changed --> items
  flow -- reference --> screen
  outside -- request --> order_undo
  order_undo -- pending --> order
  outside -- request --> order_lines
  order_lines -- rows --> order
  order_lines -- contents --> order
  order_lines -- line --> order
  order_lines -- removed --> order_undo
  order_lines -- row_removed --> order
  order_undo -- restored --> order
  order_lines -- changed --> order
  order_lines -- row_changed --> order
  order_lines -- adding --> order
  order_lines -- row_added --> order
  order_lines -- saved --> order
```
