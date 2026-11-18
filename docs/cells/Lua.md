# Lua cells

[Lua scripting guide](../LuaScripting.md) · [File format](../FileFormat.md)

A `lua` fence transforms earlier results or constructs data locally. It does
not send queries itself.

````text
```cell_config
title: Example service health
var: health
chart: billboard
attributes: gauge, max(100), style(circular)
```
```lua
return { rows = { { healthy = 98 } } }
```
````

## Configuration

| Key | Meaning |
|---|---|
| `title` | Cell heading |
| `var` | One result name, exposed as `results.name` |
| `chart`, `attributes`, `height`, `query` | [Shared display options](../ChartConfiguration.md) |
| `widget-id` | Managed by [widget publishing](../PublishingWidgets.md) |

Lua does not use a cell's NRQL account or timeout settings. Its `config` global
reflects document settings, not cell overrides. Without `cell_config`, a
leading `-- Comment` supplies the heading.

Supply a result with `return value` or `emit(value)`; an emitted value takes
precedence. For chartable data, return a table with `rows`, as above.
See the [Lua guide](../LuaScripting.md) for actual result shapes, helpers,
transformations, and runtime limits.
