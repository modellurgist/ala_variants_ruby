# Screens::Catalog

```mermaid
flowchart LR
  screen[[Screens::Catalog]]
  records[records: Records]
  add_line[add_line: AddLine]
  feed[feed: Subscription]
  records -- rows --> screen
  records -- record --> screen
  records -- form --> screen
  records -- created --> screen
  records -- updated --> screen
  records -- deleted --> screen
  records -- created → push --> publish_1([Publish])
  records -- updated → push --> publish_1([Publish])
  records -- deleted → push --> publish_1([Publish])
  add_line -- added --> screen
  feed -- product --> screen
  feed -- stock --> screen
```
