# Screens::Catalog

```mermaid
flowchart LR
  screen[[Screens::Catalog]]
  records[records]
  list_update[list_update]
  row_update[row_update]
  row_removal[row_removal]
  add_line[add_line]
  records -- rows --> screen
  records -- record --> screen
  records -- form --> screen
  records -- created --> list_update
  records -- updated --> row_update
  records -- deleted --> row_removal
  add_line -- added --> screen
```
