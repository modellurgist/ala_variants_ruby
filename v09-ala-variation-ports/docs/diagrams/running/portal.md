# Screens::Portal, as it ran

```mermaid
flowchart LR
  screen[[Screens::Portal]]
  subgraph order [order: OrderLines]
  order_lines[lines]
  end
  catalog[catalog]
  add_line[add_line]
  items[items]
  feed[feed]
  outside -- request --> add_line
  outside -- request --> catalog
  outside -- request --> feed
  outside -- request --> order
  add_line -- added --> screen
  catalog -- rows --> screen
  feed -- product_added --> screen
  feed -- product_changed --> screen
  feed -- product_removed --> screen
  feed -- stock --> screen
  order -- changed --> items
  order -- contents --> screen
  order -- restored --> screen
  order -- rows --> screen
  order -- undo_pending --> screen
  outside -- request --> order_lines
  order_lines -- adding --> order
  order_lines -- changed --> order
  order_lines -- contents --> order
  order_lines -- line --> order
  order_lines -- removed --> order
  order_lines -- row_added --> order
  order_lines -- row_changed --> order
  order_lines -- row_removed --> order
  order_lines -- rows --> order
  order_lines -- saved --> order
```
