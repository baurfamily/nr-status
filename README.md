# NR Status

An app to view data from your New Relic account. 

## Disclaimer

This is current a passion project of mine. I love playing with data and I wanted to learn more about SwiftUI. There are a lot of rough edges in this app but if you find a niche that works for you, it can be a powerful tool to visualize your data.

## Features

### Desktop Widgets!
<img width="1098" alt="Widget Examples" src="https://github.com/user-attachments/assets/ea4d0898-afb6-4506-9513-b23987b5a3ff" />

### NRQL Editor
<img width="1263" alt="Editor Example" src="https://github.com/user-attachments/assets/2186b07e-22cc-4997-b854-d182604c8264" />

Notebook files are registered as **NR Markdown** (`.nrmd`): plain-text Markdown
with NRQL, Lua, Nerdgraph, and configuration cells. Existing `.nrql` notebooks
can be renamed to `.nrmd`; their contents do not need to change.

#### API keys and accounts

In Settings, add a named API key (and its API host), then **Test & Load Accounts**.
Search accounts by name or ID, select the ones you commonly use, and **Save**.
You can also enter preferred account IDs as CSV. Secrets are stored in Keychain;
documents contain only the names you assign. The existing key and account settings
are migrated to a profile named `Default`.

Lua scripts and `{{ }}` expressions can read the effective document settings
through `config.accounts` (an ordered, 1-based list of account IDs) and
`config.api_key` (the saved key's name, never its secret). Document overrides
take precedence over the selected profile's defaults, even without an explicit
`config` block. Cell-level overrides do not change this global. For example,
`config.accounts[1]` reads the first account, and GraphQL variables can use
`{"accountId": {{ config.accounts[1] }}}`. Without any configured accounts,
the list is empty. Each Lua evaluation receives its own snapshot; editing it
does not change document settings. Results that reference `config` become stale
when these effective settings change, including account order.

Declare document data with `var appName = "Foo"` (or `var: appName = "Foo"`)
inside the config comment. It is available only as `config.appName`
in scripts and interpolation. Declarations are evaluated in order as Lua
expressions, so they can use earlier variables through `config`; strings,
numbers, booleans, and tables are supported. Names must be unique and cannot
replace `config.accounts` / `config.api_key`. Missing values and
invalid expressions are reported, not silently ignored.

Markdown sections also expand `{{ }}` expressions before rendering, including
headings such as `# {{ config.appName }}` and text such as
`Tags: {{ results.tagCount }}`. They refresh as available results or settings
change, without rewriting the source or automatically running queries.
HTML and PDF exports use the same substitutions.

Keychain entries are named `NR Status named API key (<key name>)`, and the account
field also uses the configured name. Both follow renames; the UUID is kept in a
separate identifier attribute. Existing UUID-based labels and account fields are
updated the next time you save the key.

The toolbar groups **Collapse All / Expand All** and document configuration
separately, with **Clear Results / Run All** paired at the far right. **Clear Results**
cancels pending runs and removes all cached query/script results, charts, and errors
from the document without changing its code or configuration. Use the configuration group's
**Key** and **Accounts** icon dropdowns
to override the document's connection; accounts support multiple selections from
the selected key's preferred list. Overrides automatically add or update a
`config` cell at the very top of the document. **Default** means inherit from
Settings, not a copied key name or account list. The key and building icons stay
fixed to keep the native control group joined when selections change. Key names,
account selections, and checkmarks appear inside the menus, not in the toolbar.

Click the **Document Config** gear button to reveal and expand that cell for manual
editing. New blocks include optional `author` and `description` metadata fields.
With both dropdowns at **Default**, no connection overrides are stored (and the
cell need not exist until opened). Its cell has the same collapse toggle as code cells and is included
in **Collapse All** and **Expand All**. Explicit overrides are stored as:

````text
```config
/***
author:
description:
api-key: Production
accounts: 123, 456
***/
```

```nrql
/***
title: Errors in staging
api-key: Staging
accounts: 789, 101
***/
SELECT count(*) FROM TransactionError
```
````

Each query independently overrides `api-key`, `accounts`, or both in its existing
`/*** ... ***/` metadata comment. Non-empty document settings also require that
block-comment format inside the `config` fence; bare fields and `//` settings are
not accepted.
Only `api-key` and `accounts` affect document connection settings. Other
`key: value` metadata is accepted without affecting execution and is preserved
when the toolbar changes connection settings.
A leading `//` line supplies only the query title, and only when the query has no
metadata block. Missing fields inherit document defaults, then the
app's default key and that key's preferred accounts. Changing only the key keeps
any explicit document account list; otherwise the selected key's preferred list
is used. Multiple accounts are sent together in one NerdGraph query.

Completion suggests saved key names and the selected key's preferred accounts.
You can still type any other accessible account ID; the preferred list is not an
allowlist. Event and attribute suggestions also use the query's effective key and
accounts. Unknown key names, empty/invalid account lists, and misplaced config
fences report errors rather than silently using another connection. Renaming or
deleting a key requires updating documents that reference its old name.

Changing the effective key or accounts marks affected cached charts and cells
that depend on them as out of date. Query-level overrides isolate settings they
replace; inherited app defaults and preferred accounts are tracked too. Running
an affected cell refreshes its stale prerequisites before using their results.

#### Nerdgraph (GraphQL) cells

Choose **Add Nerdgraph** (or **Convert To > Nerdgraph**) to edit GraphQL with
its JSON variables underneath and JSON results on the right. The results have
a **Find in JSON** box and disclosure triangles for objects and arrays.
The tree starts fully expanded, with each level indented. Field/item counts
appear only when a container is collapsed.
GraphQL errors remain visible alongside partial data, including the full
`errors` and `extensions` response fields.
The **Variables Sent** button shows the last request's interpolated variables
as formatted JSON, rather than repeating the literal GraphQL query.

Nerdgraph defaults to `chart: json`. Add `# chart: none` to hide its result pane
while keeping variable bindings available to other cells. Execution errors and
GraphQL errors remain visible even when the result data is hidden.
NRQL and Lua cells can also use `chart: json` in their metadata comments to
display results in the searchable JSON viewer instead of a chart. Their JSON
contains only the result rows as an array, without the query text, column list,
or result metadata. Lua variable bindings still use `{ nrql, columns, rows, facets }`;
changing display mode does not require rerunning the cell or change its bindings.
HTML and PDF exports respect these display modes.

GraphQL uses the same saved API keys and document defaults as NRQL, but does
not require or inherit account IDs. Supply account IDs as GraphQL arguments
or variables when the selected operation needs them. Leading `#` comments
can override `api-key` (`api_key` is also accepted), set a
`title`, and bind the result using `var`. Overrides reference saved key names, not
secret values.
Use `var` in NRQL and Lua metadata blocks too; `name` no longer binds results.

Nerdgraph supports multiple result declarations. A plain `# var: response`
binds the complete response; an expression binds an extracted value instead:

```graphql
# var: response
# var: entity = data.actor.entitySearch.results.entities[1]
# var: tagCount = #data.actor.entitySearch.results.entities[1].tags
```

Later cells read `results.entity.name` or `results.tagCount`. Expressions use
Lua's 1-based indexes and resolve `data`, `errors`, and `extensions` against
that cell's response. Each expression is evaluated independently; document
variables and earlier cell results are also available. Numeric `results[i]`
access follows exported bindings in cell/declaration order. Duplicate names or
missing paths fail the cell with a named error rather than exporting stale or
partial bindings. Successful runs still show the complete response in the JSON
viewer.

````text
```graphql
# title: Account details
# api-key: Production
# var: accountDetails

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
{
  "accountId": {{ results.accounts.rows[1].id }}
}
```

```lua
return {
  rows = {
    { name = results.accountDetails.data.actor.account.name }
  }
}
```
````

The adjacent `graphql` and optional `variables` fences are saved as one cell
(`nerdgraph` is accepted as an alternative query fence). Variables must be a
JSON object; without a variables fence they default to `{}`. GraphQL text is
sent literally, including the native metadata comments, without `{{ }}` interpolation.
Metadata is read only from comments before the first line of GraphQL code.
Only variables interpolate Lua
expressions: unquoted placeholders insert typed JSON values, including arrays
and objects; placeholders within quoted strings insert safely escaped text.
Missing results, invalid expressions, or invalid JSON report errors.
For example, `var: accountDetails` exposes the complete response as
`results.accountDetails`, including `data`.
Cells participate in **Run All**, dependency ordering, staleness tracking,
and **Clear Results**.

Completion loads the live GraphQL schema using the cell's effective API key
and offers fields, arguments, declared variables, and inline-fragment types,
with schema descriptions. Variables offer Lua completion inside `{{ }}`.
The **Nerdgraph Documentation** question-mark button opens a separate documentation
window that follows the focused query's cursor, jumping to its type, field,
or argument. Search covers all schema types, fields, arguments, input fields,
and their descriptions, not just the displayed type. The browser includes
argument types and field insertion. These features use Nerdgraph introspection
and the existing editor; no additional package is needed. If schema loading
fails, the editor/documentation window reports the error and queries can still
be run.

### Other experiments

There is a window at launch that lists some Entities in your account. This isn't currently useful for much, I got distracted by the Charts and Widgets.
