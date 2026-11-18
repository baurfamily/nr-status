# Chart configuration reference

[Documentation](README.md) · [UI configuration guide](ConfiguringCells.md)

NRQL and Lua cells share the same chart pipeline. Put these keys in the
`cell_config` fence immediately before the cell.

````text
```cell_config
title: Request volume
chart: line
height: 16
attributes: smoothed, lines, points
query: hide
```
```nrql
SELECT count(*) FROM Transaction TIMESERIES
```
````

## Display and layout

| Key | Values / behavior |
|---|---|
| `title` | Heading independent of the result variable name |
| `chart` | `line`, `bar`, `pie`, `plot`, `billboard`, `table`, `json`, or `none`; GraphQL also supports `bindings` to show data that has been saved in variables from results. |
| `attributes` | Chart-specific tokens separated by spaces and/or commas |
| `height` | Positive whole display lines, **15 points per line**; omit or use `auto` for automatic sizing |
| `query` | `hide` starts code collapsed and excludes it from HTML/PDF exports; omit or use `show` to include code |

Automatic sizing is 20 lines for plots/tables and content-fit for billboards.
An explicit billboard height reflows its tiles to fit the available area.
HTML/PDF use the configured chart height; exported tables remain data tables,
not fixed-height images. Oversized query/chart blocks shrink to fit PDF pages.

`query: hide` does not follow live expand/collapse state. Manually expanding
code does not include it in an export when this setting is active.

Chart choices depend on result shape. Automatic chooses an appropriate
supported type; an incompatible explicit chart type does not force that chart.
GraphQL displays JSON, bindings, or hidden output rather than these charts.

## Attributes by chart

| Chart | Tokens | Defaults when `attributes` is omitted |
|---|---|---|
| `line` | `stacked`, `smoothed`, `lines`, `points` | Smoothed lines; no stacking or points |
| `bar` | `pivot` | No pivot |
| `pie` | `donut`, `separated` | Donut with separated segments |
| `plot` | `color-facets`, `x-log`, `y-log`, `x(field)`, `y(field)`, `color(field)`, `size(field)` | Facet colors; linear axes; automatic fields |
| `billboard` | `gauge`, `max(number)`, `style(styleName)` | Values without gauges; gauge maximum 100 and linear style |
| `table` | None | Data table |

**Omitting `attributes` keeps defaults. Providing it turns unlisted toggles
off.** An empty `attributes:` disables applicable toggles. Line charts always
keep at least lines or points enabled; listing neither falls back to lines.

Scatter field names are used as written, so match their case to result fields.
Use numeric fields for axes and sizes. Gauge maximum must be finite and positive.
Supported gauge style names are `linear`, `compactLinear`, `linearCapacity`,
`circular`, and `circularCapacity`.

```text
chart: plot
attributes: color-facets, x(Latency), y(Requests), size(Errors)
```

```text
chart: billboard
attributes: gauge, max(100), style(circular)
```

## Non-chart modes

- `chart: none` hides output but keeps result bindings available.
- `chart: json` uses the searchable JSON viewer. For NRQL/Lua, it shows the
  row array only; bindings still expose the full result envelope.
- `chart: bindings` is for GraphQL: expressions and their extracted values,
  exported as a table in HTML/PDF.

Errors remain visible when result data is hidden.

Facet/field selection and display-count controls are interactive only; they
are not serialized as workbook chart configuration. Filter the query itself
when the selection must persist.

## Widget presentation

Small and medium widgets hide axes; small widgets also hide legends. Larger
legends appear only when they fit in two lines. Category bars omit legends
that duplicate visible category labels. Tables use a static grid and report
remaining rows when space runs out.

For reproducible examples of every chart type, open
[`ChartSamples.nrmd`](examples/ChartSamples.nrmd).
