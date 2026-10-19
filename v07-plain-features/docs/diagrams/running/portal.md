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
  outside -- request --> add_line
  outside -- request --> catalog
  outside -- request --> flow
  outside -- request --> order
  add_line -- added --> screen
  catalog -- rows --> screen
  flow -- blocked --> screen
  flow -- form --> screen
  flow -- reference --> screen
  flow -- step --> screen
  order -- changed --> items
  order -- contents --> totals
  order -- restored --> screen
  order -- rows --> screen
  order -- undo_pending --> screen
  totals -- summary --> screen
  outside -- request --> order_lines
  outside -- request --> order_undo
  order_lines -- adding --> order
  order_lines -- changed --> order
  order_lines -- contents --> order
  order_lines -- line --> order
  order_lines -- removed --> order_undo
  order_lines -- row_added --> order
  order_lines -- row_changed --> order
  order_lines -- row_removed --> order
  order_lines -- rows --> order
  order_lines -- saved --> order
  order_undo -- pending --> order
  order_undo -- restored --> order_lines
```
