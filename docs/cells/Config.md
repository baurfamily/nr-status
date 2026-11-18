# Document configuration

[File format](../FileFormat.md) · [Variables and bindings](../VariablesAndBindings.md)

An optional `config` fence sets workbook-wide defaults. It must be the first
cell, and a workbook may contain only one.

````text
```config
author: Example team
description: Service overview
api-key: Production
accounts: 123456, 789012
var appName = "Checkout"
var heading = config.appName .. " health"
```
````

| Setting | Meaning |
|---|---|
| `api-key` | Saved API key **name**, never the secret; `api_key` is an alias |
| `accounts` | Nonempty comma-separated account IDs used by NRQL |
| `var name = expression` | Document data exposed as `config.name`; `var: name = expression` also works |
| `author`, `description` | Optional descriptive metadata; no execution effect |

Omit connection fields to inherit Settings. Other key/value metadata is
preserved without affecting execution. `//` lines are comments.
Duplicate connection fields, invalid/empty account lists, unknown saved keys,
and misplaced configuration produce errors rather than silently selecting
another connection.

Variables are evaluated in declaration order. Names must be unique and cannot
replace `accounts` or `api_key`. Refer to earlier declarations through `config`,
not as bare Lua globals.

NRQL cells can override the key and/or accounts in `cell_config`. GraphQL cells
can override the key but receive account IDs through their own query arguments
or JSON variables. A key-only override keeps an explicit document account list;
otherwise it uses the selected key's preferred accounts.

See [configuration controls](../ConfiguringCells.md) to edit these settings
without writing fences.
