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
  outside -- request --> lines
  outside -- request --> pricing
  outside -- request --> saved
  outside -- request --> undo
  outside -- request --> wishlist
  items -- added --> lines
  lines -- adding --> items
  lines -- changed --> items
  lines -- contents --> totals
  lines -- line --> wishlist
  lines -- removed --> undo
  lines -- row_added --> screen
  lines -- row_changed --> screen
  lines -- row_removed --> screen
  lines -- rows --> screen
  lines -- saved --> saved
  pricing -- discount --> totals
  pricing -- promo_applied --> screen
  pricing -- promo_rejected --> screen
  pricing -- shipping_method --> totals
  saved -- changed --> saved
  saved -- changed --> saved_store
  saved -- count --> screen
  saved -- moved --> lines
  saved -- rows --> screen
  saved -- rows_changed --> screen
  totals -- summary --> screen
  undo -- pending --> screen
  undo -- restored --> lines
  wishlist -- added --> screen
  wishlist -- changed --> wishlist_store
  wishlist -- count --> screen
  wishlist -- dropped --> screen
  wishlist -- ids --> screen
  wishlist -- rows --> screen
  wishlist -- rows_changed --> screen
  wishlist -- taken --> lines
```
