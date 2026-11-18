# Document configuration

[File format](../FileFormat.md) · [Variables and bindings](../VariablesAndBindings.md)

Optional YAML frontmatter sets workbook-wide defaults. It is the first cell,
delimited by `---` at the very top of the file.

````text
---
author: Example team
description: Service overview
api-key: Production
accounts: [123456, 789012]
bindings:
  - name: appName
    expression: '"Checkout"'
  - name: heading
    expression: config.appName .. " health"
---
````

| Setting | Meaning |
|---|---|
| `api-key` | Saved API key **name**, never the secret; `api_key` is an alias |
| `accounts` | Nonempty YAML list of account IDs used by NRQL; a CSV scalar also works |
| `bindings` | An array of `{ name, expression }` mappings; values are exposed as `config.name` |
| `author`, `description` | Optional descriptive metadata; no execution effect |

Omit connection fields to inherit Settings. Other key/value metadata is
preserved without affecting execution. Use YAML `#` comments and quote strings
containing colons or comment characters. Multiline descriptions can use `|`.
Duplicate connection fields, invalid/empty account lists, unknown saved keys,
and malformed YAML produce errors rather than silently selecting
another connection.

Bindings are evaluated in array order. Each entry requires a Lua-identifier
`name` and a nonempty Lua `expression`. Names must be unique and cannot replace
`accounts` or `api_key`. Refer to earlier bindings through `config`, not as bare
Lua globals. Keep Lua string quotes inside YAML quotes, as in
`expression: '"Checkout"'`.

Document configuration does not use `var`; that key names a cell's whole result.

NRQL cells can override the key and/or accounts in `cell_config`. GraphQL cells
can override the key but receive account IDs through their own query arguments
or JSON variables. A key-only override keeps an explicit document account list;
otherwise it uses the selected key's preferred accounts.

When expanded, the Document Config cell renders its values as a summary.
Use its gear to edit Settings or YAML text; its disclosure button collapses the
summary. See [configuration controls](../ConfiguringCells.md).
