# Documentation

## App guides

- [Using the app](UsingTheApp.md): API keys, editor shortcuts, discovery, bindings inspector, and exports.
- [AI Assist](AIAssist.md): draft cells with your own CLI, with source review and no chat interface.
- [Configuration controls](ConfiguringCells.md): document and cell sidebars, display modes, and chart resizing.
- [Publishing widgets](PublishingWidgets.md): publish, update, recover, and remove desktop widgets.

## Workbook reference

- [File format basics](FileFormat.md): fences, document defaults, and a complete small workbook.
- [Variables and bindings](VariablesAndBindings.md): document variables, result bindings, and NRQL/GraphQL interpolation.
- [Chart configuration](ChartConfiguration.md): display modes, chart attributes, and sizing.
- [Lua scripting](LuaScripting.md): reading results and returning or emitting derived data.

### Cell reference

| Cell | Purpose |
|---|---|
| [Document config](cells/Config.md) | Connection defaults, metadata, and document variables |
| [Markdown](cells/Markdown.md) | Narrative, headings, and interpolated values |
| [NRQL](cells/NRQL.md) | New Relic data queries and charts |
| [GraphQL / Nerdgraph](cells/GraphQL.md) | NerdGraph operations, JSON variables, and extracted bindings |
| [Lua](cells/Lua.md) | Transform earlier results or create local data |

## Examples and maintenance

- [Chart samples](examples/ChartSamples.nrmd): every chart type, with fixed offline data.
- [Bindings walkthrough](examples/Bindings.nrmd): real NerdGraph queries, literal and extracted bindings, and connected Lua reports.
- [Busiest app](examples/BusiestApp.nrmd): a connected-query example requiring New Relic access.
- [Screenshot capture guide](Screenshots.md).
- [Development and widget troubleshooting](Development.md).
- [Historical editor design notes](EditorImprovements.md) (not a current user reference).
