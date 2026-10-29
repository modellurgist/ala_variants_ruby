# Screens::Cart, as it ran

```mermaid
flowchart LR
  screen[[Screens::Cart]]
  subgraph order [order: OrderLines]
  order_lines[lines]
  order_undo[undo]
  end
  saved[saved]
  wishlist[wishlist]
  pricing[pricing]
  totals[totals]
  items[items]
  saved_store[saved_store]
  wishlist_store[wishlist_store]
  feed[feed]
  outside -- request --> feed
  outside -- request --> order
  outside -- request --> pricing
  outside -- request --> saved
  outside -- request --> wishlist
  feed -- stock --> screen
  items -- added --> order
  order -- adding --> items
  order -- changed --> items
  order -- contents --> totals
  order -- line --> wishlist
  order -- restored --> screen
  order -- row_added --> screen
  order -- row_changed --> screen
  order -- row_removed --> screen
  order -- rows --> screen
  order -- saved --> saved
  order -- undo_pending --> screen
  pricing -- discount --> totals
  pricing -- promo_applied --> screen
  pricing -- promo_rejected --> screen
  pricing -- shipping_method --> totals
  saved -- changed --> saved
  saved -- changed --> saved_store
  saved -- count --> screen
  saved -- moved --> order
  saved -- rows --> screen
  saved -- rows_changed --> screen
  totals -- summary --> screen
  wishlist -- added --> screen
  wishlist -- changed --> wishlist_store
  wishlist -- count --> screen
  wishlist -- dropped --> screen
  wishlist -- ids --> screen
  wishlist -- rows --> screen
  wishlist -- rows_changed --> screen
  wishlist -- taken --> order
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
