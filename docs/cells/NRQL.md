# NRQL cells

[File format](../FileFormat.md) · [Chart configuration](../ChartConfiguration.md)

An `nrql` fence runs a query against the effective saved API key and account
list, displaying a chart, table, or JSON.

````text
```cell_config
title: Requests by application
var: requests
chart: bar
accounts: 123456
timeout: 120
```
```nrql
SELECT count(*) AS requests FROM Transaction FACET appName SINCE 1 hour ago
```
````

## Configuration

| Key | Meaning |
|---|---|
| `title` | Cell heading |
| `var` | One result name, accessible as `results.name` |
| `api-key` / `api_key` | Saved key name override |
| `accounts` | Comma-separated account ID override |
| `timeout` | Positive whole seconds; default **30**; NRQL only |
| `chart`, `attributes`, `height`, `query` | [Shared display options](../ChartConfiguration.md) |
| `widget-id` | Managed by [widget publishing](../PublishingWidgets.md) |

`timeout` and cell-level key overrides are available in the configuration
sidebar's **Text** editor. The HTTP deadline is at least 90 seconds and at least
30 seconds longer than the query timeout.

Use `{{ LuaExpression }}` in query text to reuse data. The expanded expression
is inserted as text without quoting or escaping. Supply quotes for string
placeholders and appropriately escape values that contain quotes or backslashes.
There are no built-in list-formatting helpers. See
[variables and bindings](../VariablesAndBindings.md).

Bindings expose the result envelope (`rows`, `columns`, `facets`, and `nrql`),
not just the visible JSON array. `chart: none` hides output without removing
the binding; `chart: json` displays only the rows.

Without `cell_config`, a leading `// Comment` supplies the heading.
