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
  payment_news[payment_news]
  stock_news[stock_news]
  outside -- request --> charge
  outside -- request --> flow
  outside -- request --> lines
  outside -- request --> pricing
  charge -- charged --> flow
  charge -- charged --> payment_news
  charge -- charged --> settle
  charge -- declined --> flow
  charge -- declined --> payment_news
  flow -- blocked --> screen
  flow -- done --> screen
  flow -- form --> screen
  flow -- ready_to_pay --> screen
  flow -- step --> screen
  lines -- contents --> totals
  pricing -- discount --> totals
  pricing -- shipping_method --> totals
  settle -- stock_changed --> stock_news
  totals -- summary --> screen
```
