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
  outside -- request --> wishlist
  wishlist -- rows --> screen
  wishlist -- count --> screen
  wishlist -- ids --> screen
  outside -- request --> saved
  saved -- rows --> screen
  saved -- count --> screen
  outside -- request --> pricing
  pricing -- discount --> totals
  totals -- summary --> screen
  pricing -- shipping_method --> totals
  outside -- request --> order
  order -- undo_pending --> screen
  order -- rows --> screen
  order -- contents --> totals
  order -- changed --> items
  order -- row_changed --> screen
  order -- row_removed --> screen
  order -- saved --> saved
  saved -- changed --> saved_store
  saved -- changed --> saved
  saved -- rows_changed --> screen
  saved -- moved --> order
  order -- adding --> items
  items -- added --> order
  order -- row_added --> screen
  order -- restored --> screen
  order -- line --> wishlist
  wishlist -- changed --> wishlist_store
  wishlist -- added --> screen
  wishlist -- rows_changed --> screen
  wishlist -- dropped --> screen
  pricing -- promo_applied --> screen
  pricing -- promo_rejected --> screen
  wishlist -- taken --> order
  outside -- request --> order_undo
  order_undo -- pending --> order
  outside -- request --> order_lines
  order_lines -- rows --> order
  order_lines -- contents --> order
  order_lines -- changed --> order
  order_lines -- row_changed --> order
  order_lines -- row_removed --> order
  order_lines -- saved --> order
  order_lines -- adding --> order
  order_lines -- row_added --> order
  order_lines -- removed --> order_undo
  order_undo -- restored --> order_lines
  order_lines -- line --> order
```
