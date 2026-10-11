# Screens::Portal

```mermaid
flowchart LR
  screen[[Screens::Portal]]
  lines[lines: CartLines]
  undo[undo: Undo]
  catalog[catalog: Records]
  add_line[add_line: AddLine]
  totals[totals: OrderTotals]
  flow[flow: SubmitOrder]
  products[products: ProductIndex]
  items[items: CartItemsStore]
  lines -- items → lookup --> items
  lines -- products → lookup --> products
  lines -- changed → apply --> items
  lines -- adding → add --> items
  lines -- rows --> screen
  lines -- contents → contents --> totals
  lines -- removed → capture --> undo
  undo -- pending --> screen
  catalog -- rows --> screen
  add_line -- added --> screen
  totals -- summary --> screen
  flow -- lines → lines --> lines
  flow -- step --> screen
  flow -- form --> screen
  flow -- blocked --> screen
  flow -- reference --> screen
  items -- added → arrived --> lines
```
