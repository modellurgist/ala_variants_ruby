# Screens::Checkout

```mermaid
flowchart LR
  screen[[Screens::Checkout]]
  lines[lines]
  totals[totals]
  pricing[pricing]
  flow[flow]
  charge[charge]
  settle[settle]
  status[status]
  stock_update[stock_update]
  lines -- contents --> totals
  pricing -- discount --> totals
  pricing -- shipping_method --> totals
  totals -- summary --> screen
  flow -- step --> screen
  flow -- form --> screen
  flow -- blocked --> screen
  flow -- ready_to_pay --> screen
  flow -- done --> screen
  charge -- charged --> settle
  charge -- charged --> flow
  charge -- charged --> status
  charge -- declined --> flow
  charge -- declined --> status
  settle -- stock_changed --> stock_update
```
