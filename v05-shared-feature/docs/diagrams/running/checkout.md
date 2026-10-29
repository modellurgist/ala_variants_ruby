# Screens::Checkout, as it ran

```mermaid
flowchart LR
  screen[[Screens::Checkout]]
  lines[lines: CartLines]
  pricing[pricing: PricingChoices]
  totals[totals: CartTotals]
  flow[flow: CheckoutFlow]
  charge[charge: Charge]
  settle[settle: SettleOrder]
  products[products: ProductIndex]
  items[items: CartItemsStore]
  feed[feed: Subscription]
  lines -- items → lookup --> items
  lines -- products → lookup --> products
  lines -- contents → contents --> totals
  pricing -- discount → discount --> totals
  pricing -- shipping_method → shipping_method --> totals
  totals -- summary --> screen
  flow -- lines → lines --> lines
  flow -- step --> screen
  flow -- form --> screen
  flow -- blocked --> screen
  flow -- ready_to_pay --> dataflowport_1([DataFlow port])
  flow -- done --> screen
  charge -- charged → settle --> settle
  charge -- charged → succeeded --> flow
  charge -- declined → failed --> flow
  charge -- charged → push --> publish_2([Publish])
  charge -- declined → push --> publish_3([Publish])
  settle -- stock_changed → push --> publish_4([Publish])
  feed -- outcome --> screen
```
