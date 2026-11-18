# Markdown cells

[File format](../FileFormat.md) · [Variables and bindings](../VariablesAndBindings.md)

Text outside recognized fences is Markdown. Use it for headings, explanations,
links, and summaries. Edit the text in the cell; moving focus away renders it.

````text
# {{ config.appName }}

This workbook compares request volume and errors.

```swift
// Ordinary code examples stay Markdown, not executable cells.
```
````

`{{ LuaExpression }}` expands against `config` and currently available
`results` before rendering. Rendering does not run queries or rewrite the
source. HTML/PDF exports use the same substitutions.

## Configuration

A preceding `cell_config` can store publication metadata:

````text
```cell_config
widget-id: 11111111-2222-3333-4444-555555555555
```
# Service overview
````

Normally, let [widget publishing](../PublishingWidgets.md) create this ID.
Markdown headings determine the cell's heading in the editor; Markdown does not
use query chart settings or produce a result binding.
