# Configuration controls

[Documentation](README.md) · [Chart option reference](ChartConfiguration.md)

## Document defaults

Use the toolbar's **Key** and **Accounts** dropdowns to choose a workbook's
connection. **Default** inherits Settings rather than copying the current
values. Explicit overrides create/update YAML frontmatter at the top.

Choose the **Document Config** gear to open its sidebar. It includes author,
description, API key name, accounts, and document variables.
**Settings** presents fields; **Text** edits the same saved configuration.

Expand **Document Config** with its disclosure button to see a rendered summary
of the saved values. Collapsing it hides the summary; the gear opens the editing
sidebar independently.

Under **Bindings**, add rows with separate **Name** and Lua expression fields,
just like GraphQL extractions. These edit the frontmatter `bindings` array;
read their values as `config.name`. See [variables and bindings](VariablesAndBindings.md).

## Cell settings

Click a code cell's **gear** to open its configuration sidebar. You can
configure a cell before running it.

| Control | Use |
|---|---|
| Title | Set the heading independently of any binding |
| Variable binding / Whole response variable | Name the complete NRQL/Lua result or GraphQL response |
| Bindings (GraphQL) | Add/remove extractions with separate Name and Lua expression fields |
| Account IDs | Override NRQL routing for this cell |
| Hide query on open and export | Start code collapsed; exclude code from HTML/PDF |
| Display | Automatic chart, explicit chart type, JSON, Hidden, or GraphQL Bindings |
| Chart height (lines) | Positive whole display lines; leave blank for Auto |

**Settings** and **Text** edit the same YAML `cell_config`; changes are saved in
the workbook. Text mode shows the body—you do not need to type fence markers.
YAML quoting, comments, lists, and multiline strings work there. Settings writes
properly quoted YAML and preserves unrelated fields.
In GraphQL Settings, **Add Binding** creates an extraction row; its minus button
removes it. These rows edit the `bindings` array without changing the whole
response variable.
Use it for advanced options such as a cell's `api-key: SavedName` override or an
NRQL `timeout: 120`. These do not have individual Settings controls.

Press **Esc** in configuration expressions for completion of `config`,
`results`, and, for GraphQL extractions, fields in the current response.
**Remove Cell Configuration** removes the cell's saved overrides.

## Configure a chart

1. Choose **Display**, then a supported chart type. Running the cell reveals
   which types its result supports.
2. Adjust the type-specific controls: line/point styling, pie segments, bar
   pivoting, scatter fields/log axes, or billboard gauges.
3. Set **Chart height (lines)**, or drag the grip at the bottom of the chart.
   The grip snaps to whole lines and saves on release; double-click for Auto.

Auto uses 20 lines for plots/tables and fits billboard content. Explicit
billboard heights reflow their tiles to fit. Chart types, attributes, and
heights persist; temporary facet/field selections and display counts do not.
Use query filters for persistent data selection.

For token names, defaults, and examples, see [chart configuration](ChartConfiguration.md).

## Published cells

Published cells show a **Published** badge. Their sidebar's **Update Widget**
refreshes the saved publication without another naming dialog. Editing a cell
alone does not update its desktop widget; see [publishing widgets](PublishingWidgets.md).
