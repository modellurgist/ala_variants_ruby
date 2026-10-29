# Screens::Catalog, as it ran

```mermaid
flowchart LR
  screen[[Screens::Catalog]]
  records[records]
  add_line[add_line]
  feed[feed]
  publish_added[publish_added]
  publish_changed[publish_changed]
  publish_removed[publish_removed]
  publish_stock[publish_stock]
  outside -- request --> add_line
  outside -- request --> feed
  outside -- request --> records
  add_line -- added --> screen
  feed -- product_added --> screen
  feed -- product_changed --> screen
  feed -- product_removed --> screen
  feed -- stock --> screen
  records -- created --> publish_added
  records -- deleted --> publish_removed
  records -- form --> screen
  records -- record --> screen
  records -- rows --> screen
  records -- updated --> publish_changed
  records -- updated --> publish_stock
```
