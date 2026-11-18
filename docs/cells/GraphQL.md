# GraphQL / Nerdgraph cells

[File format](../FileFormat.md) · [Variables and bindings](../VariablesAndBindings.md)

Use a `graphql` fence (`nerdgraph` is an alias) for NerdGraph operations. An
optional following `variables` fence supplies a JSON object; absent variables
default to `{}`. Together they are one cell.

````text
```cell_config
title: Account details
api-key: Production
var: 'response'
bindings:
  - name: 'accountName'
    expression: 'data.actor.account.name'
chart: bindings
```
```graphql
query AccountDetails($accountId: Int!) {
  actor {
    account(id: $accountId) {
      id
      name
    }
  }
}
```
```variables
{ "accountId": {{ config.accounts[1] }} }
```
````

## Configuration

| Key | Meaning |
|---|---|
| `title` | Cell heading |
| `api-key` / `api_key` | Saved key name override |
| `var: name` | Bind the complete response, including `data`, `errors`, and `extensions` |
| `bindings` | An array of `{ name, expression }` Lua extractions or `{ name, value }` literal strings |
| `chart` | Default/`json`, `bindings`, or `none` |
| `query: hide` | Collapse code on open and omit it from HTML/PDF exports |

`var` is optional and names the complete response; it is not a list or an
expression. Each `bindings` entry has a `name` and exactly one of `expression`
(nonempty Lua) or `value` (literal text). You can use `var`, `bindings`, or both.
Binding names must be Lua identifiers and unique across `var` and the array.
Quote expressions starting with `#`, such as `expression: "#data.actor.entities"`.
Expressions can read `data`,
`errors`, `extensions`, document `config`, and other cells' `results`.
Use Lua's **1-based** indexes, even though the JSON viewer labels arrays from
zero. Later cells read `results.response.data...` or `results.accountName`.

GraphQL uses the selected API key but does **not** inherit NRQL account routing.
Supply account IDs as arguments or variables when the operation requires them.

## Interpolation and errors

GraphQL query text is sent literally: `{{ }}` works **only in JSON variables**.
Unquoted placeholders insert typed JSON values; quoted placeholders insert
escaped string content. See the [binding reference](../VariablesAndBindings.md#graphql-input-variables).

JSON is the default output. Bindings mode lists each source and its value;
Hidden suppresses the result data, not errors. Partial data and GraphQL errors
remain inspectable. If any binding extraction fails, no bindings from that run
are exported to other cells, although the response and per-binding diagnostics
remain visible.

Use the [app guide](../UsingTheApp.md#graphql-tools) for JSON search, creating
bindings from a response, and browsing the live schema.
