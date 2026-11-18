# Variables and bindings

[Documentation](README.md) · [Lua scripting](LuaScripting.md)

Keep document data, result bindings, and GraphQL request variables distinct:

| Kind | Defined in | Read as |
|---|---|---|
| Document data | A `bindings` array in frontmatter | `config.name` |
| Cell result binding | `var: name` inside `cell_config` | `results.name` |
| GraphQL binding | A `bindings` array in `cell_config` | `results.name` |
| GraphQL request variable | JSON in a `variables` fence | `$name` in the GraphQL operation |

Open [Bindings.nrmd](examples/Bindings.nrmd) for a runnable walkthrough using
real NerdGraph queries and your configured New Relic access.

## Document variables

````text
---
bindings:
  - name: appName
    value: Checkout
  - name: services
    expression: '{ "Checkout", "Payments" }'
  - name: heading
    expression: config.appName .. " overview"
---
````

Each entry has a Lua-identifier `name` and exactly one source:

| Key | Meaning |
|---|---|
| `value` | Literal string; no Lua evaluation or extra Lua quoting |
| `expression` | Nonempty Lua expression producing a string, number, boolean, or table |

`value: Checkout` stores `"Checkout"`; even `value: 42` stores the string `"42"`.
Empty/null YAML values become empty strings; use `value: "null"` for that text.
Normal YAML quoting still applies to special characters and multiline strings.

Bindings are installed in array order; expressions can read earlier `config`
fields. Names must be unique; `accounts` and `api_key` are reserved.

`config.accounts` is the effective document account list (1-based), and
`config.api_key` is the effective saved key **name**, never its secret. Both
include inherited Settings defaults. Cell overrides do not change this global.
Each Lua evaluation gets its own snapshot; mutating it does not edit the document.

## Bind a cell's result

For NRQL and Lua, set one `var: name`:

````text
```cell_config
var: traffic
chart: none
```
```nrql
SELECT count(*) AS requests FROM Transaction FACET appName
```
````

Read `results.traffic.rows` in Lua or interpolation. NRQL/Lua bindings are result
envelopes, not raw JSON rows; see [Lua result access](LuaScripting.md).
Changing the display to JSON or Hidden does not change the binding.
The old `name:` key is not a result binding.

Only exported bindings appear in `results`. `results[1]` is the first
exported binding, **not the first workbook cell**. GraphQL can export several
bindings: the whole-response `var` first, then `bindings` array order.
Prefer named references: they are easier to
maintain and required for widget dependencies.

## NRQL and Markdown interpolation

`{{ expression }}` evaluates Lua and inserts text:

````text
```nrql
SELECT count(*) FROM Transaction
WHERE appName = '{{ config.appName }}'
```
````

Text interpolation does **not** quote or escape values. The example above is
suitable for the fixed demo name; values containing quotes or backslashes need
appropriate NRQL escaping before insertion. Arrays cannot be inserted directly
as an `IN` list, and there are no built-in `values`, `names`, or `column`
helpers. Construct appropriately quoted and escaped NRQL text explicitly when
building dynamic lists. See [Lua scripting](LuaScripting.md) for supported
interpolation values and limitations.

Markdown uses the same text expansion, including headings:
`# {{ config.heading }}`. It updates from available results/configuration
without automatically running a query or changing the saved source.

## GraphQL input variables

GraphQL operation text is literal. Declare `$variables` there and interpolate
inside the adjacent JSON object:

````text
```graphql
query AccountDetails($accountId: Int!) {
  actor { account(id: $accountId) { id name } }
}
```
```variables
{ "accountId": {{ config.accounts[1] }} }
```
````

An **unquoted** placeholder inserts a typed JSON value: number, boolean, string,
array, or object. A placeholder **inside quotes** inserts escaped text:

```text
{ "filter": "name = '{{ config.appName }}'" }
```

The final variables value must be a JSON object. Invalid JSON, missing values,
or invalid Lua expressions produce errors. **Variables Sent** shows the
interpolated JSON actually used by the last request.

## GraphQL output bindings

GraphQL supports both complete-response and extracted bindings:

```yaml
var: response
bindings:
  - name: entity
    expression: data.actor.entitySearch.results.entities[1]
  - name: tagCount
    expression: "#data.actor.entitySearch.results.entities[1].tags"
  - name: environment
    value: Production
```

`var` names the complete response; it cannot contain an extraction expression
or a list. The optional `bindings` array contains named Lua expressions or
literal strings. Each entry requires a Lua-identifier `name` and exactly one
of `expression` or `value`, using the same rules as document bindings.
Names must not collide with each other or the whole-response variable.
Quote expressions starting with `#` so YAML does not treat them as comments.
Expressions resolve `data`, `errors`, and
`extensions` against the current response. `config` and other cells' `results`
are also available. Expressions are independent: do not reference a sibling
binding as though it had already been exported.

Later cells read `results.entity.name` or `results.tagCount`. Duplicate names,
missing paths, or extraction errors prevent successful export; if any extraction
fails, none of that run's bindings are made available to consumers. The
response remains visible for diagnosis.

Literal `value` text is not scanned for dependencies or evaluated as Lua.
Document configuration uses the same `bindings` record format, but its values
live under `config`, not `results`. Unlike GraphQL extractions, document bindings
can reference earlier bindings in the same array through `config.name`.

## Running connected cells

Use named references such as `results.traffic` or `results["traffic"]` so the app
can discover dependencies. Running a cell runs missing or stale named
prerequisites first; **Run All** respects those dependencies.
Computed or positional access does not provide the same named dependency
tracking. Keep producers above consumers for a readable workbook.

Changes to source, upstream results, or effective connection/configuration
can make results out of date. Rerun consumers to refresh them.
**Clear Results** cancels pending runs and clears cached results and errors
without changing source or configuration.

The toolbar's **Bindings** inspector shows document variables, result bindings,
and pending/error/out-of-date states. See [using the app](UsingTheApp.md#bindings-inspector).
