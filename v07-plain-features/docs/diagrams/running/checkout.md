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
  feed[feed]
  publish_stock[publish_stock]
  publish_paid[publish_paid]
  publish_declined[publish_declined]
  outside -- request --> charge
  outside -- request --> feed
  outside -- request --> flow
  outside -- request --> lines
  outside -- request --> pricing
  charge -- charged --> flow
  charge -- charged --> publish_paid
  charge -- charged --> settle
  charge -- declined --> flow
  charge -- declined --> publish_declined
  feed -- declined --> screen
  feed -- paid --> screen
  flow -- blocked --> screen
  flow -- done --> screen
  flow -- form --> screen
  flow -- ready_to_pay --> screen
  flow -- step --> screen
  lines -- contents --> totals
  pricing -- discount --> totals
  pricing -- shipping_method --> totals
  settle -- stock_changed --> publish_stock
  totals -- summary --> screen
```
