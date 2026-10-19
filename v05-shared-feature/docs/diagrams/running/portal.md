# Screens::Portal, as it ran

```mermaid
flowchart LR
  screen[[Screens::Portal]]
  subgraph order [order: OrderLines]
  order_lines[lines: CartLines]
  order_undo[undo: Undo]
  end
  catalog[catalog: Records]
  add_line[add_line: AddLine]
  totals[totals: OrderTotals]
  flow[flow: SubmitOrder]
  products[products: ProductIndex]
  items[items: CartItemsStore]
  order -- items → lookup --> items
  order -- products → lookup --> products
  order -- changed → apply --> items
  order -- adding → add --> items
  order -- fetch → fetch --> items
  order -- rows --> screen
  order -- contents → contents --> totals
  order -- undo_pending --> screen
  order -- restored --> screen
  order_lines -- removed → capture --> order_undo
  order_lines -- items --> order
  order_lines -- products --> order
  order_lines -- changed --> order
  order_lines -- adding --> order
  order_lines -- rows --> order
  order_lines -- row_added --> order
  order_lines -- row_changed --> order
  order_lines -- row_removed --> order
  order_lines -- contents --> order
  order_lines -- saved --> order
  order_lines -- line --> order
  order_undo -- pending --> order
  order_undo -- restored --> order
  catalog -- rows --> screen
  add_line -- added --> screen
  totals -- summary --> screen
  flow -- lines → lines --> order
  flow -- step --> screen
  flow -- form --> screen
  flow -- blocked --> screen
  flow -- reference --> screen
  items -- added → arrived --> order
  items -- found → arrived --> order
```
