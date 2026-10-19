# Screens::Cart, as it ran

```mermaid
flowchart LR
  screen[[Screens::Cart]]
  lines[lines]
  items[items]
  totals[totals]
  undo[undo]
  saved[saved]
  wishlist[wishlist]
  saved_store[saved_store]
  wishlist_store[wishlist_store]
  pricing[pricing]
  outside -- request --> undo
  undo -- pending --> screen
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
  outside -- request --> lines
  lines -- rows --> screen
  lines -- contents --> totals
  lines -- removed --> undo
  lines -- row_removed --> screen
  undo -- restored --> lines
  lines -- row_added --> screen
  lines -- changed --> items
  lines -- row_changed --> screen
  lines -- saved --> saved
  saved -- changed --> saved_store
  saved -- changed --> saved
  saved -- rows_changed --> screen
  saved -- moved --> lines
  lines -- adding --> items
  items -- added --> lines
  lines -- line --> wishlist
  wishlist -- changed --> wishlist_store
  wishlist -- added --> screen
  wishlist -- rows_changed --> screen
  wishlist -- dropped --> screen
  wishlist -- taken --> lines
  pricing -- promo_applied --> screen
  pricing -- promo_rejected --> screen
```
