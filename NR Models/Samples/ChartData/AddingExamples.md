
```gql
query {
  actor {
    nrql(accounts:265881, query:"FROM Transaction SELECT *") {
      metadata {
          eventTypes
        facets
        timeWindow {
          begin
          end
          since
          until
        }
      }
      results
      nrql
    }
  }
}

```
