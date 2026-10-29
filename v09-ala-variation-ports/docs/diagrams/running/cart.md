# Screens::Cart, as it ran

```mermaid
flowchart LR
  screen[[Screens::Cart]]
  subgraph order [order: OrderLines]
  order_lines[lines]
  end
  pricing[pricing]
  totals[totals]
  items[items]
  feed[feed]
  outside -- request --> feed
  outside -- request --> order
  outside -- request --> pricing
  feed -- stock --> screen
  items -- added --> order
  order -- adding --> items
  order -- changed --> items
  order -- contents --> totals
  order -- line --> screen
  order -- restored --> screen
  order -- row_added --> screen
  order -- row_changed --> screen
  order -- row_removed --> screen
  order -- rows --> screen
  order -- saved --> screen
  order -- undo_pending --> screen
  pricing -- discount --> totals
  pricing -- promo_applied --> screen
  pricing -- promo_rejected --> screen
  pricing -- shipping_method --> totals
  totals -- summary --> screen
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
