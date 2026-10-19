# Screens::Catalog, as it ran

```mermaid
flowchart LR
  screen[[Screens::Catalog]]
  records[records]
  list_update[list_update]
  row_update[row_update]
  row_removal[row_removal]
  add_line[add_line]
  outside -- request --> add_line
  outside -- request --> records
  add_line -- added --> screen
  records -- created --> list_update
  records -- deleted --> row_removal
  records -- form --> screen
  records -- record --> screen
  records -- rows --> screen
  records -- updated --> row_update
```
