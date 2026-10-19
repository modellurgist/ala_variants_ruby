# Screens::Checkout, as it ran

```mermaid
flowchart LR
  screen[[Screens::Checkout]]
  lines[lines]
  pricing[pricing]
  totals[totals]
  flow[flow]
  charge[charge]
  settle[settle]
  items[items]
  stock_update[stock_update]
  status[status]
  outside -- request --> charge
  outside -- request --> flow
  outside -- request --> lines
  outside -- request --> pricing
  charge -- charged --> flow
  charge -- charged --> settle
  charge -- charged --> status
  charge -- declined --> flow
  charge -- declined --> status
  flow -- blocked --> screen
  flow -- done --> screen
  flow -- form --> screen
  flow -- ready_to_pay --> screen
  flow -- step --> screen
  lines -- contents --> totals
  pricing -- discount --> totals
  pricing -- shipping_method --> totals
  settle -- stock_changed --> stock_update
  totals -- summary --> screen
```
