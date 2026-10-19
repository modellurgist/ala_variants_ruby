# Screens::Catalog, as it ran

```mermaid
flowchart LR
  screen[[Screens::Catalog]]
  records[records]
  add_line[add_line]
  list_update[list_update]
  row_update[row_update]
  row_removal[row_removal]
  outside -- request --> records
  records -- rows --> screen
  outside -- request --> add_line
  add_line -- added --> screen
  records -- form --> screen
  records -- created --> list_update
  records -- record --> screen
  records -- updated --> row_update
  records -- deleted --> row_removal
```
