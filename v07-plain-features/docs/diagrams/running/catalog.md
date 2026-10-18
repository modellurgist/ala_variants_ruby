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
  records -- form --> screen
  records -- created --> list_update
  records -- rows --> screen
  outside -- request --> add_line
  add_line -- added --> screen
  records -- updated --> row_update
  records -- record --> screen
  records -- deleted --> row_removal
```
