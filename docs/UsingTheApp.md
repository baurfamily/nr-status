# Using NR Status

[Documentation](README.md)

## Connect to New Relic

1. Open **Settings > API Keys** and choose **Add API Key**.
2. Give the key a recognizable name, enter its API host and New Relic user API key.
3. Choose **Test & Load Accounts**, search by account name or ID, and select preferred accounts.
4. Choose **Save**. Use **Use as app default** to make it the default connection.

Secrets live in Keychain. Workbooks reference the saved name, not the secret.
Preferred accounts are defaults and completion suggestions, not an allowlist;
you can enter any account ID the key can access. Update workbook references
if you rename or delete a saved key.

For an offline first look, open [ChartSamples.nrmd](examples/ChartSamples.nrmd)
and choose **Run All**. It uses fixed Lua data with no key or network needed.

## Work in a notebook

Use **File > New** for a saveable workbook, or open a `.nrmd` file. Cell menus
and the **Editor** menu let you add, duplicate, move, convert, or delete cells.
Combine Markdown explanations with NRQL, GraphQL, and Lua cells.

Run the focused cell with **Command-Return**, or use **Run All** in the toolbar.
Named prerequisites run first when needed. **Clear Results** cancels pending
runs and clears results/errors without deleting source.
**Collapse All / Expand All** controls code visibility.

Use **AI Assist** in the document toolbar to draft a workbook with your own
AI CLI, or the small sparkles button in a cell header to write or improve that
cell. Configure the command in **Settings > AI Assist**, describe what you want,
and choose **Generate**. Valid cell drafts replace the targeted cell; document
drafts append new cells. One **Undo** reverts the entire AI edit, including
commentary and additional cells. Ambiguous or malformed drafts remain open for
correction. Generated code is never run automatically.
See [AI Assist](AIAssist.md) for command setup and what source is shared.

| Shortcut | Action |
|---|---|
| Command-Return | Run focused query/script |
| Command-Shift-Return | Run all queries |
| Shift-Return | Insert a newline |
| Tab | Accept the visible completion |

In **Settings > Editor**, **Return accepts autocomplete** and **Return runs
query** are both on by default. Completion takes priority when enabled.
Command-Return and Shift-Return keep their meanings regardless of those settings.

Use the toolbar's **Key** and **Accounts** menus for document connection
overrides. **Default** means inherit Settings. Account selection supports
multiple preferred accounts. These controls update the document's saved
configuration; see [configuration controls](ConfiguringCells.md).

## NRQL completion

The editor suggests keywords, functions, event types, and attributes using the
effective connection. In a `WHERE` comparison, type an opening quote after
`=`, `!=`, `<>`, `IN (`, or `NOT IN (` to suggest observed string values.

Value suggestions follow completed time ranges/timezones, defaulting to the
last hour. Lookups are cached and limited to 100 unique values; numeric values,
computed attributes, subqueries, and multi-event queries are not suggested.
Incomplete time clauses defer the lookup.

## GraphQL tools

Choose **Add Nerdgraph** in a cell menu, or convert an existing cell.
The editor shows the operation and its JSON variables with results beside it.

- Use **Find in JSON** to search and disclosure triangles to explore objects/arrays.
- **Variables Sent** shows the interpolated JSON used by the last request.
- Right-click a JSON field/value and choose **Add Binding to This Value…**,
  enter a name, then rerun the cell to populate the new `bindings` extraction.
  Selecting the JSON root sets `var` instead, if it is not already set.
- In the configuration sidebar, **Settings** names the **Whole response variable**;
  the **Bindings** tab edits the expression/value binding rows.
- In the cell's configuration, choose **Display > Bindings** to inspect
  extraction expressions and values; choose **JSON** for the complete response.
- Use the **Nerdgraph Documentation** question-mark button for the live schema
  browser. It follows the cursor, supports search, and can insert fields.

Schema completion uses the effective API key. A schema-loading failure does
not prevent running a query. JSON array labels start at zero, but extraction
expressions use Lua's **1-based** indexes.

## Bindings inspector

The toolbar's **Bindings** button opens a workbook-wide view of document
variables and cell result bindings. Row-count links inspect NRQL/Lua results
in a table; GraphQL bindings expose their JSON values.

Bindings are grouped under source cells. **Jump to Cell** reveals and focuses
the producer. Pending, duplicate, failed, and out-of-date markers help diagnose
connected workbooks. See [variables and bindings](VariablesAndBindings.md)
for the underlying rules.

## Query Builder

Open **Features > Query Builder** to explore events, attributes, and summaries
without starting from a blank query. Its **Account** picker scopes discovery
and queries to the default key's preferred accounts; **Default (all preferred
accounts)** combines them. This is local to the Query Builder window and does
not change Settings.

Facet selection filters the displayed chart. **Filter Query to Selected
Facets** can add a `WHERE` clause for a single facet when you want a query-level
filter rather than a temporary chart selection.

## Export

Use **File > Export** for NRQL text, HTML, or PDF. Run the desired cells first
to include their current results. HTML/PDF honor display modes, configured chart
height, Markdown substitutions, and **Hide query on open and export**.
Exporting does not turn a workbook into a live dashboard.

Next: [configure cells](ConfiguringCells.md) or [publish a desktop widget](PublishingWidgets.md).
