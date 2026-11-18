# NR Markdown file format

[Documentation](README.md) · [Cell reference](README.md#cell-reference)

A workbook is a UTF-8 plain-text **`.nrmd`** file: Markdown, optional YAML
frontmatter, and fenced cells.
You can edit it in NR Status or a text editor. Saved files contain source and
configuration, not fetched results or execution state.

## Cell boundaries

| Text | Meaning |
|---|---|
| Text outside recognized fences | A Markdown cell |
| `nrql` fence | An NRQL query |
| `graphql` or `nerdgraph` fence | A NerdGraph query |
| `lua` fence | A Lua script |
| Leading `---` block | YAML document configuration; optional, at the very top |
| `cell_config` fence | YAML configuration for the immediately following code or Markdown cell |
| `variables` fence after GraphQL | JSON input variables belonging to that GraphQL cell |

Use triple backticks on their own line to close a fence. Blank lines inside a
code fence do not split cells. Blank lines between prose stay in the same
Markdown cell. Unrecognized code fences, such as `swift`, remain Markdown.
Keep `cell_config` adjacent to its cell and `variables` adjacent to its GraphQL
query; blank separator lines are fine.

Document frontmatter opens and closes with `---`, like a conventional Markdown
document. A closing `...` is also accepted. Horizontal rules elsewhere are
ordinary Markdown, not additional configuration blocks.

## A small workbook

Replace `Production` and the account ID with your saved key name and account:

````text
---
api-key: Production
accounts: [123456]
bindings:
  - name: appName
    expression: '"Checkout"'
---

# {{ config.appName }}

Requests during the last hour.

```cell_config
title: Request count
var: requests
chart: billboard
```
```nrql
SELECT count(*) AS requests FROM Transaction
WHERE appName = '{{ config.appName }}' SINCE 1 hour ago
```

```cell_config
title: Double the requests
chart: billboard
```
```lua
return { rows = { { doubled = results.requests.rows[1].requests * 2 } } }
```
````

## Configuration syntax

Configuration uses **YAML mappings**: quoted strings, `#` comments, multiline
strings, and lists are supported. Quote values containing `: ` or ` #`, including
Lua expressions using the length operator. Do not repeat YAML keys.
Document variables and GraphQL extractions use a `bindings` array of
`{ name, expression }` records. Cell `var` is one whole-result name.

```yaml
description: |
  A multiline workbook description.
accounts: [123456, 789012]
bindings:
  - name: appName
    expression: '"Checkout"'
  - name: heading
    expression: config.appName .. " health"
```

The old `config` fence and non-YAML declarations are no longer supported.

Document defaults and cell overrides are separate:

- [Frontmatter](cells/Config.md) sets the saved API key name, account defaults, and document variables.
- `cell_config` sets a cell's title, result binding, connection overrides, and display options.
- Omitted connection fields inherit from the document, then Settings. Never put API key secrets in a workbook.

The [cell references](README.md#cell-reference) list applicable options.
[Chart configuration](ChartConfiguration.md) covers the shared display keys;
[variables and bindings](VariablesAndBindings.md) covers `var`, `bindings`, and `{{ }}`.

## Titles and widget identities

Without a `cell_config` fence, a code cell's first comment can supply its title:
`//` for NRQL, `--` for Lua, or `#` for GraphQL. Any cell configuration—even an
empty fence—disables that fallback; use `title:` instead.

Publishing adds a `widget-id` to the cell's configuration. Keep it when editing
the same published cell. Duplicating a cell in the app gives the copy a separate
identity. See [publishing widgets](PublishingWidgets.md) for snapshot behavior.
