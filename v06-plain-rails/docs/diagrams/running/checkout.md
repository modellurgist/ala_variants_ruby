# Screens::Checkout, as it ran

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
  outside -- request --> lines
  lines -- contents --> totals
  totals -- summary --> screen
  outside -- request --> flow
  flow -- step --> screen
  flow -- form --> screen
  flow -- ready_to_pay --> screen
  outside -- request --> pricing
  pricing -- discount --> totals
  pricing -- shipping_method --> totals
  outside -- request --> charge
  charge -- declined --> flow
  charge -- declined --> status
  charge -- charged --> settle
  settle -- stock_changed --> stock_update
  charge -- charged --> flow
  flow -- done --> screen
  charge -- charged --> status
  flow -- blocked --> screen
```
