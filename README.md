# NR Status

An app to view data from your New Relic account. 

## Disclaimer

This is current a passion project of mine. I love playing with data and I wanted to learn more about SwiftUI. There are a lot of rough edges in this app but if you find a niche that works for you, it can be a powerful tool to visualize your data.

## Features

### Desktop Widgets!

The **Workbook** widget displays a chart or Markdown cell published from an
NR Markdown workbook. In the cell's menu, choose **Publish as Widget**, give it
a name, and save the workbook. Add a Workbook widget to the desktop, then
choose that name in **Edit Widget**. Manage publications under
**Features > Published Widgets**.

Use **Unpublish Widget** in the cell menu to remove its publication. Republishing
the cell reconnects widgets using the same saved identity. The widget picker and
Published Widgets window organize cells under their source filenames. In the
**Document Config** header, **Publish All Widgets** publishes all chart and
Markdown cells or updates their existing publications, preserving custom names.
The confirmation sheet lists the cells before publishing.

For repeatable chart and widget comparisons, open
[`docs/examples/ChartSamples.nrmd`](docs/examples/ChartSamples.nrmd). It contains
fixed Lua data for billboard, line, bar, pie, scatter plot, and table charts and
requires no API key or network access.

Publishing stores a snapshot of the entire workbook in the shared App Group.
The extension refreshes the chosen cell and its transitive dependencies without
requiring the app to be open. Source edits are not automatically synchronized:
use **Update Published Widget** on the same cell to publish them. A saved
`widget-id` in the cell's configuration keeps the reference stable through title
changes and moves; duplicated cells do not inherit that identity. Markdown cells
also support an adjacent `cell_config` fence for this metadata; it is not rendered.
Publishing an unsaved workbook is allowed, but save it to retain the identity.

Widget dependencies must use named references (`results.name` or
`results["name"]`), not positional or computed references. Missing/ambiguous
dependencies, cycles, and Nerdgraph mutations/subscriptions are rejected.
Connection and chart settings come from the workbook, with named API keys still
resolved through Keychain. Widgets request a refresh after five minutes, subject
to WidgetKit scheduling. A failed refresh retains the last successful output and
marks it as stale.

The old chart-specific widgets have been replaced, not migrated. Remove old
desktop widgets and add **Workbook** widgets after installing the rebuilt app.
The extension now has a new bundle ID and requires its own development
provisioning profile. Do not delete system widget caches to install it.

During development, keep only the current app build registered with macOS.
Older test builds with the same app bundle ID can prevent WidgetKit from
resolving the new configuration intent, leaving a placeholder with no **Edit
Widget**. Unregister obsolete app paths with Launch Services rather than deleting
widget caches; unregistering an extension alone does not remove its containing
app's intent registration.

The configuration intent belongs only to the widget extension; do not compile
it into the app as well. Test-host builds add sandbox permissions that normal
builds do not have, so verify configuration using a normal signed app build.
Both targets enable App Groups registration for automatic provisioning and must
have profiles authorizing `group.net.baurhome.NR-Status`. This registered group
shares Keychain items even if the targets have different App ID prefixes. Saved
keys are copied from the original access group when first used; the old copy is
kept until the profile is deleted. Workbook storage remains in the original
macOS App Group.

### NRQL Editor
<img width="1263" alt="Editor Example" src="https://github.com/user-attachments/assets/2186b07e-22cc-4997-b854-d182604c8264" />

Notebook files are registered as **NR Markdown** (`.nrmd`): plain-text Markdown
with NRQL, Lua, Nerdgraph, and configuration cells.

#### Cell configuration

Each code cell has a gear button that opens a sidebar spanning its header, code,
and results. Configure its title, result bindings, connection overrides, display
mode, and chart settings there, even before running it. **Settings** and **Text**
edit the same configuration; changes are saved directly in the document.
Configuration fences are hidden by default.

A `cell_config` fence immediately precedes the cell it configures. It uses the
same keys for NRQL, Lua, and Nerdgraph; document defaults use a separate `config`
fence at the top of the file. Neither fence needs a comment wrapper:

````text
```cell_config
title: Error rate
var: error_rate
chart: billboard
attributes: gauge, max(100), style(circular)
```
```nrql
SELECT percentage(count(*), WHERE error IS true) FROM Transaction
```
````

Supported chart attributes include `stacked`, `smoothed`, `lines`, `points`,
`donut`, `separated`, `pivot`, `color-facets`, `x-log`, `y-log`, and `gauge`.
Gauges also accept `max(number)` and `style(styleName)`; scatter plots accept
`x(field)`, `y(field)`, `color(field)`, and `size(field)`. An absent attributes
line uses chart defaults; an explicit empty line switches applicable toggles off.
Facet/field filtering and display counts are not stored in workbook configuration.
Set `height: 20` in a `cell_config` fence, or use **Chart height (lines)** in the
sidebar, to size a chart in display lines (15 points per line). Omit `height`, or
set it to `auto`, for the default: 20 lines for plots and tables, and content-fit
for billboards. Explicitly sized billboards automatically reflow into rows and
columns that give their values and gauges the largest size that fits the available
width and height, keeping result order. Shorter charts can fit more items per row.
HTML and PDF exports use the same chart height;
table exports remain data tables rather than fixed-height images.
Oversized chart/query blocks are reduced to fit a PDF page without clipping.
Drag the grip along a chart's bottom edge to resize it, snapping to whole lines.
The chart updates while dragging; releasing saves the height to `cell_config`.
Double-click the grip to reset to Auto.
In the query builder, facet selections filter the chart, and **Filter Query to
Selected Facets** can add a `WHERE` clause for a single facet.

With no `cell_config` fence, the first code line can supply the title via a
`//` NRQL comment, `--` Lua comment, or `#` GraphQL comment. Any cell configuration,
even an empty fence, disables that fallback; use `title:` instead.

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
inside the document `config` fence. It is available only as `config.appName`
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

Click the **Document Config** gear button to open its configuration sidebar.
New blocks include optional `author` and `description` metadata fields.
With both dropdowns at **Default**, no connection overrides are stored (and the
cell need not exist until opened). Explicit overrides are stored as:

````text
```config
author:
description:
api-key: Production
accounts: 123, 456
```

```cell_config
title: Errors in staging
api-key: Staging
accounts: 789, 101
```
```nrql
SELECT count(*) FROM TransactionError
```
```
````

Each query independently overrides `api-key`, `accounts`, or both in its
`cell_config` fence. Document settings are plain key/value lines inside the
`config` fence; `//` lines are comments, not settings.
Only `api-key` and `accounts` affect document connection settings. Other
`key: value` metadata is accepted without affecting execution and is preserved
when the toolbar changes connection settings.
Missing fields inherit document defaults, then the
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

Nerdgraph defaults to JSON. Set `chart: none` in its `cell_config` to hide its result pane
while keeping variable bindings available to other cells. Execution errors and
GraphQL errors remain visible even when the result data is hidden.
NRQL and Lua cells can also use `chart: json` in their `cell_config` to
display results in the searchable JSON viewer instead of a chart. Their JSON
contains only the result rows as an array, without the query text, column list,
or result metadata. Lua variable bindings still use `{ nrql, columns, rows, facets }`;
changing display mode does not require rerunning the cell or change its bindings.
HTML and PDF exports respect these display modes.

GraphQL uses the same saved API keys and document defaults as NRQL, but does
not require or inherit account IDs. Supply account IDs as GraphQL arguments
or variables when the selected operation needs them. The `cell_config` fence
can override `api-key` (`api_key` is also accepted), set a
`title`, and bind the result using `var`. Overrides reference saved key names, not
secret values.
Use `var` in NRQL and Lua configuration too; `name` does not bind results.

Nerdgraph supports multiple result declarations. A plain `var: response`
binds the complete response; an expression binds an extracted value instead:

```cell_config
var: response
var: entity = data.actor.entitySearch.results.entities[1]
var: tagCount = #data.actor.entitySearch.results.entities[1].tags
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
```cell_config
title: Account details
api-key: Production
var: accountDetails
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
sent literally, including comments, without `{{ }}` interpolation.
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
