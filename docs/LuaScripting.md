# Lua scripting

Lua cells transform query results into tables, charts, or printed reports. Use NRQL or GraphQL
cells to fetch data, then read their bindings through `results` in Lua. Lua cells
cannot run queries or make network requests themselves.

This guide covers the scripting environment and data shapes. See
[File format](FileFormat.md) for fences,
[Variables and bindings](VariablesAndBindings.md) for configuration and naming,
[Chart configuration](ChartConfiguration.md) for presentation, and
[Using the app](UsingTheApp.md) for execution controls. Cell-specific references:
[Lua](cells/Lua.md), [NRQL](cells/NRQL.md), [GraphQL](cells/GraphQL.md), and
[Markdown](cells/Markdown.md).

## Bind a query, then transform its result

Put `var: name` in the query's `cell_config` fence to expose its result as
`results.name`. `title` is independent of the binding name.

````markdown
```cell_config
title: Response time by minute
var: latency
```
```nrql
FROM Transaction
SELECT average(duration) AS seconds
SINCE 30 minutes ago
TIMESERIES 1 minute
```

```cell_config
title: Response time in milliseconds
var: latency_ms
chart: line
```
```lua
local source = assert(results.latency, "Run the latency query first")
local rows = {}
for _, row in ipairs(source.rows) do
  if type(row.seconds) == "number" then
    rows[#rows + 1] = {
      beginTimeSeconds = row.beginTimeSeconds,
      endTimeSeconds = row.endTimeSeconds,
      milliseconds = row.seconds * 1000,
    }
  end
end
return { rows = rows }
```
````

The Lua result uses the same table/chart pipeline as NRQL. Binding it as
`latency_ms` lets subsequent cells read `results.latency_ms.rows`.
`chart: none` hides a result without preventing it from being bound.

## Reading results

| Expression | Meaning |
|---|---|
| `results.latency` | A successfully loaded result bound as `latency`. |
| `results["top apps"]` | Bracket access for a binding whose name is not a Lua identifier. |
| `results[1]` | The first currently available exported binding, not cell number 1. |
| `#results` | Number of currently available exported bindings. |
| `config.accounts[1]` | First effective document account ID. |
| `config.api_key` | Saved API key **name**, never the secret key; may be `nil`. |
| `config.appName` | Document binding named `appName` in the frontmatter `bindings` array. |

Only named, successfully loaded results enter `results`. Unnamed NRQL/Lua cells
do not occupy numeric slots; a GraphQL cell can contribute several bindings.
Numeric indices follow document order and binding order within each cell, and
can change as results become available. Prefer names.

A missing binding is `nil`; indexing it further raises a Lua error. Check both
the binding and row existence when empty results are possible:

```lua
local source = assert(results.latency, "Missing latency result")
local first = source.rows[1]
return { rows = { { firstSeconds = first and first.seconds or 0 } } }
```

`results` prevents ordinary assignment to its top-level entries
(`results.latency = ...` errors). It is not a deeply immutable table: nested
tables can be changed within a run. Build new rows when deriving data rather
than relying on mutations or on named and numeric access sharing table identity.
Changes do not update the source cell's stored result.

### Execution and dependencies

Running a cell first runs its detected dependencies if their results are missing
or stale; Run All executes cells in dependency order. Detection scans Lua code
and interpolation expressions for literal references such as `results.latency`
or `results["latency"]`. Computed keys such as `results[key]` and numeric indices
do **not** establish those dependencies; run their sources explicitly.

Despite the usual source-before-consumer layout, `results` contains available
bindings from across the document, not only cells above the current cell.
References to cells below can be scheduled too. Avoid cycles: there is no
dedicated cycle error, and a missing result can instead surface during execution.

## NRQL and Lua result shape

An NRQL result, or the stored result of a Lua cell, has this structure:

```lua
{
  nrql = "FROM Transaction SELECT count(*) FACET appName",
  columns = { "count" },
  rows = {
    { facet = "Shop", count = 120 },
    { facet = "API", count = 80 },
  },
  facets = { "appName" },
}
```

* `rows` is a 1-based list of field tables.
* `columns` lists decoded data-field names; special row fields such as `facet`
  and time bounds are separate. Use the actual keys, not SELECT expressions you
  assume will be returned. Aliases make scripts easier to maintain.
* `facets`, when present, lists facet **attribute names**. A row's `facet`
  contains its value: a string for one facet, or a list of strings for multiple
  facets.
* Time-series rows carry `beginTimeSeconds` and `endTimeSeconds`. Event rows may
  carry `timestamp`. All three are Unix times in **seconds** in Lua.
* Comparison rows carry `comparison = "current"` or `"previous"`. Preserve it
  when preserving comparison semantics; filter previous rows and omit the field
  when producing a current-only result.
* Ordinary fields can be numbers, strings, numeric lists, string lists, or
  string-keyed numeric tables (for example percentile values). Use bracket
  syntax for punctuation: `row["average.duration"]` or
  `row["percentile.duration"]["95"]`.

This is the app's decoded result, not the complete raw NerdGraph response.
Unsupported field types are not retained by the result decoder.

### Returning or emitting a result

A Lua cell must supply either a result table with `rows`, or a bare list of row
tables:

```lua
return {
  { facet = "Successful", count = 95 },
  { facet = "Failed", count = 5 },
}
```

The equivalent explicit form is:

```lua
emit({ rows = {
  { facet = "Successful", count = 95 },
  { facet = "Failed", count = 5 },
} })
```

`emit(value)` selects the cell's one result; it does not append another chart.
The last `emit` wins, and an emitted value takes precedence over `return`.
Calling `emit()` selects `nil`, which is not a valid data/chart result.

* `return { rows = {} }` produces an empty result.
* A scalar or a list containing non-row values fails result conversion.
  A missing return value also fails unless using Console. To chart a scalar, wrap it:
  `return { rows = { { total = 42 } } }`.
* `nrql` and `facets` are optional output metadata. `nrql` defaults to `""`.
  Output `columns` is ignored: fields are inferred from the rows and sorted
  within each row for stable ordering.
* There is no `timeseries` flag. Preserve both time-bound fields for time-series
  output, and use `facet` on rows for faceted output. Keep structural fields
  consistent across rows; result classification uses the first row.
* Numbers, strings, homogeneous numeric/string lists and numeric dictionaries
  survive the chart-result decoder. Arbitrary nested objects, booleans and
  nulls are not general-purpose chart fields. Convert them to supported values.
  Avoid non-finite numbers and sparse/mixed-key lists.

## Reading GraphQL bindings

GraphQL bindings retain JSON structure, not the NRQL `rows` wrapper. A plain
`var: response` binds the whole response, including `data`, `errors` and
`extensions` when present. An extraction binding exposes only its selected
value:

````markdown
```cell_config
var: 'response'
bindings:
  - name: 'entities'
    expression: 'data.actor.entitySearch.results.entities'
```
```graphql
{
  actor {
    entitySearch(query: "domain = 'APM' AND type = 'APPLICATION'") {
      results { entities { name guid tags { key values } } }
    }
  }
}
```

```cell_config
chart: table
```
```lua
local entities = assert(results.entities, "Run the entity search first")
local rows = {}
for _, entity in ipairs(entities) do
  rows[#rows + 1] = {
    name = entity.name,
    guid = entity.guid,
    tagCount = #(entity.tags or {}),
  }
end
return { rows = rows }
```
````

Here `results.entities[1].name` and
`results.response.data.actor.entitySearch.results.entities[1].name` access the
same response path. JSON objects become keyed Lua tables, arrays become 1-based
lists, and JSON null becomes `nil`; account for missing/null fields, especially
when iterating lists. A null array element can create a hole, and `ipairs` stops
at the first `nil`. Numbers are bridged through Lua's numeric representation, so
do not rely on exact large-integer preservation.

The globals `data`, `errors` and `extensions` are available while evaluating
GraphQL extraction expressions, **not** in ordinary Lua cells. Use
`results.response.data` there instead. Returning a GraphQL object directly only
works as a Lua cell result if it already has a supported row-list shape;
otherwise transform it as above.

## Console output

Use **Display > Console** in a Lua cell's Settings, or set `chart: console`,
to show `print()` output instead of a chart:

````text
```cell_config
title: Service report
chart: console
```
```lua
print("Service", "Checkout")
print(string.format("Healthy: %.1f%%", 98.5))
```
````

No `return` or `emit` is required. Each `print` adds a line; multiple arguments
are separated by tabs. Output is plain, selectable, monospaced text, not Markdown.
It appears after execution, replaces the previous run's output, and is removed
by **Clear Results**. Text printed before an error remains visible.

Console output is included in HTML/PDF exports and published widgets.
If you also return or emit data, use the normal row-list shape: `var` still binds
that data, not the printed text. Print-only cells export no result binding.

## Helpers and configuration

The app supplies `emit` and `print`, plus the `results` and `config` tables.
`print(...)` is visible in Console mode; other display modes keep their existing
chart/JSON output. Use `assert`/`error` for actionable failure messages.

There are no built-in `query`, `names`, `column` or `values` helpers. Use standard
Lua or define local helpers in each script. For example:

```lua
local function column(result, field)
  local values = {}
  for _, row in ipairs(result.rows) do
    if row[field] ~= nil then values[#values + 1] = row[field] end
  end
  return values
end

local values = column(assert(results.latency), "seconds")
local total = 0
for _, value in ipairs(values) do total = total + value end
return { rows = { { meanSeconds = #values > 0 and total / #values or 0 } } }
```

That example averages returned buckets equally; it is not a transaction-weighted
average across the original events.

`config` reflects effective **document** settings, including inherited defaults,
not per-cell routing overrides. Its account list is empty when none is set.
Document `bindings` are installed in array order. A `value` is a literal string;
an `expression` evaluates Lua, can read earlier `config` fields, and must produce
a non-nil JSON-compatible value. Bindings are not bare globals and are installed
before `results` is available.
Changes to `config` during a run do not change document settings.

Each script run and each interpolation expression gets a fresh Lua VM. Globals,
local helper functions and mutations do not persist to another cell or
placeholder. Export reusable data as a cell binding, not as a global variable.

## Interpolation is not a Lua cell

`{{ expression }}` evaluates a Lua **expression**, not a block of statements.
It can read the same `results` and `config` values, but its output follows the
destination's rules rather than the Lua cell's result-table rules.

| Destination | Accepted output and insertion |
|---|---|
| NRQL text | String, number or boolean, inserted as text. |
| Markdown text | The same textual substitution; no automatic Markdown escaping. |
| GraphQL `variables` JSON, outside a JSON string | JSON-compatible value, encoded as a typed JSON value, including lists/objects. |
| GraphQL `variables` JSON, inside a JSON string | String, number or boolean, inserted as escaped JSON string content. |

GraphQL operation text itself is not interpolated. Put dynamic inputs in its
`variables` fence, whose expanded value must be a JSON object.

For example, an NRQL cell can use:

```nrql
FROM Transaction SELECT count(*)
WHERE appName = '{{ config.appName }}'
LIMIT {{ math.min(100, 20) }}
```

NRQL interpolation does **not** quote or escape values. The quotes above belong
to the query; a value containing a quote needs appropriate NRQL escaping.
Lua's `string.format("%q", value)` produces a Lua literal, not a general NRQL
escaping helper. Tables are not automatically expanded into `IN (...)` lists;
construct any such textual list explicitly with appropriate escaping.

GraphQL variables can instead preserve types:

```json
{
  "accountId": {{ config.accounts[1] }},
  "label": "Report for {{ config.appName }}"
}
```

A `nil` placeholder is an error, not empty text or JSON null. Accessing a missing
intermediate table can fail before that check. Each placeholder is evaluated
independently. The delimiter scanner is textual and ends at the next `}}`;
avoid expressions containing that sequence (including adjacent closing braces
in table constructors).

## Supported libraries and limits

The sandbox provides ordinary Lua control flow and base functions such as
`assert`, `error`, `ipairs`, `pairs`, `pcall`, `tonumber`, `tostring` and `type`.
Standard `string`, `table`, `math`, `utf8` and `coroutine` libraries are available.
There is no app-provided JSON encoder, HTTP client, or query function.

File/process access is restricted: `io` and `debug` are removed, as are `load`,
`loadstring`, `loadfile` and `dofile`. `os` is **not** entirely removed:
time/date helpers remain, but functions for executing commands, exiting,
changing files, reading environment variables and changing locale are disabled.
`package`/`require` remain restricted to preloaded modules; filesystem module
search and dynamic library loading are disabled. You cannot load arbitrary Lua
files or native extensions.

Each VM has a 10,000,000-instruction limit and a 64,000,000-byte Lua VM memory
cap. These are execution safeguards, not a wall-clock timeout or a total app
memory guarantee. Runtime calls are serialized. Syntax errors, runtime errors,
resource-limit failures and invalid output shapes appear as cell failures;
do not rely on cancellation immediately interrupting a running script.

For a longer worked transformation, see the current-period regression example
in [BusiestApp.nrmd](examples/BusiestApp.nrmd).
