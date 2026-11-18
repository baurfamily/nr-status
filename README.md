# NR Status

**Your New Relic data, in a Mac workbook—and on your desktop.**

Explore an idea, chart the answer, and keep it close with a desktop widget.

## What it does

- **Workbooks:** combine NRQL, NerdGraph (GraphQL), Lua, and Markdown in one notebook.
- **Charts:** turn results into line, bar, pie, scatter, billboard, or table views.
- **Connected analysis:** reuse results across cells with variables and Lua.
- **Desktop widgets:** publish workbook charts and Markdown, with background refresh.
- **Discovery and sharing:** explore events and attributes, use autocomplete, and export HTML, PDF, or query text.

## Requirements

- **macOS 15 or later.**
- A New Relic account and a **New Relic user API key** with access to the data you want to query.
- Network access for live queries and widget refreshes. Local Lua examples work offline.

This is an experimental, independently developed app—not an official New Relic product.

## Get started

Add a named API key in **Settings > API Keys**, choose your preferred accounts,
and open a workbook. For a no-setup tour of the charts, open
[`ChartSamples.nrmd`](docs/examples/ChartSamples.nrmd) and choose **Run All**.

## Documentation

| I want to… | Read |
|---|---|
| Learn the editor, connections, and exports | [Using the app](docs/UsingTheApp.md) |
| Draft cells with my own AI CLI | [AI Assist](docs/AIAssist.md) |
| Configure cells and charts in the UI | [Configuration controls](docs/ConfiguringCells.md) |
| Put a workbook cell on my desktop | [Publishing widgets](docs/PublishingWidgets.md) |
| Write or edit a workbook as text | [File format](docs/FileFormat.md) |
| Look up a cell type | [Cell reference](docs/README.md#cell-reference) |
| Pass data between cells | [Variables and bindings](docs/VariablesAndBindings.md) |
| Look up chart settings | [Chart configuration](docs/ChartConfiguration.md) |
| Transform results with Lua | [Lua scripting](docs/LuaScripting.md) |

Screenshots are due for a refresh; the [capture guide](docs/Screenshots.md)
provides an offline demo and a short shot list.
