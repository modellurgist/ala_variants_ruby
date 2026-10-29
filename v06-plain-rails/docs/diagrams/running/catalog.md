# Screens::Catalog, as it ran

```mermaid
flowchart LR
  screen[[Screens::Catalog]]
  records[records]
  product_news[product_news]
  product_gone[product_gone]
  add_line[add_line]
  outside -- request --> add_line
  outside -- request --> records
  add_line -- added --> screen
  records -- created --> product_news
  records -- deleted --> product_gone
  records -- form --> screen
  records -- record --> screen
  records -- rows --> screen
  records -- updated --> product_news
```
