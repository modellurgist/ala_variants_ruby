# Screens::Checkout, as it ran

```mermaid
flowchart LR
  screen[[Screens::Checkout]]
  lines[lines]
  pricing[pricing]
  totals[totals]
  items[items]
  feed[feed]
  publish_stock[publish_stock]
  publish_paid[publish_paid]
  publish_declined[publish_declined]
  outside -- request --> feed
  outside -- request --> lines
  outside -- request --> pricing
  outside -- request --> publish_declined
  outside -- request --> publish_paid
  outside -- request --> publish_stock
  feed -- declined --> screen
  feed -- paid --> screen
  lines -- contents --> totals
  pricing -- discount --> totals
  pricing -- shipping_method --> totals
  totals -- summary --> screen
```
