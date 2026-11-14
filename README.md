# NR Status

An app to view data from your New Relic account. 

## Disclaimer

This is current a passion project of mine. I love playing with data and I wanted to learn more about SwiftUI. There are a lot of rough edges in this app but if you find a niche that works for you, it can be a powerful tool to visualize your data.

## Features

### Desktop Widgets!
<img width="1098" alt="Widget Examples" src="https://github.com/user-attachments/assets/ea4d0898-afb6-4506-9513-b23987b5a3ff" />

### NRQL Editor
<img width="1263" alt="Editor Example" src="https://github.com/user-attachments/assets/2186b07e-22cc-4997-b854-d182604c8264" />

#### API keys and accounts

In Settings, add a named API key (and its API host), then **Test & Load Accounts**.
Search accounts by name or ID, select the ones you commonly use, and **Save**.
You can also enter preferred account IDs as CSV. Secrets are stored in Keychain;
documents contain only the names you assign. The existing key and account settings
are migrated to a profile named `Default`.
Keychain entries are named `NR Status named API key (<key name>)`, and the account
field also uses the configured name. Both follow renames; the UUID is kept in a
separate identifier attribute. Existing UUID-based labels and account fields are
updated the next time you save the key.

The toolbar groups **Collapse All / Expand All** and document configuration
separately, with **Clear Results / Run All** paired at the far right. **Clear Results**
cancels pending runs and removes all cached query/script results, charts, and errors
from the document without changing its code or configuration. Use the configuration group's
**Key** and **Accounts** icon dropdowns
to override the document's connection; accounts support multiple selections from
the selected key's preferred list. Overrides automatically add or update a
`config` cell at the very top of the document. **Default** means inherit from
Settings, not a copied key name or account list. The key and building icons stay
fixed to keep the native control group joined when selections change. Key names,
account selections, and checkmarks appear inside the menus, not in the toolbar.

Click the **Document Config** gear button to reveal and expand that cell for manual
editing. With both dropdowns at **Default**, the cell is blank (and need not exist
until opened). Its cell has the same collapse toggle as code cells and is included
in **Collapse All** and **Expand All**. Explicit overrides are stored as:

````text
```config
/***
api-key: Production
accounts: 123, 456
***/
```

```nrql
/***
title: Errors in staging
api-key: Staging
accounts: 789, 101
***/
SELECT count(*) FROM TransactionError
```
````

Each query independently overrides `api-key`, `accounts`, or both in its existing
`/*** ... ***/` metadata comment. Non-empty document settings also require that
block-comment format inside the `config` fence; bare fields and `//` settings are
not accepted.
A leading `//` line supplies only the query title, and only when the query has no
metadata block. Missing fields inherit document defaults, then the
app's default key and that key's preferred accounts. Changing only the key keeps
any explicit document account list; otherwise the selected key's preferred list
is used. Multiple accounts are sent together in one NerdGraph query.

Completion suggests saved key names and the selected key's preferred accounts.
You can still type any other accessible account ID; the preferred list is not an
allowlist. Event and attribute suggestions also use the query's effective key and
accounts. Unknown key names, empty/invalid account lists, and misplaced config
fences report errors rather than silently using another connection. Renaming or
deleting a key requires updating documents that reference its old name.

### Other experiments

There is a window at launch that lists some Entities in your account. This isn't currently useful for much, I got distracted by the Charts and Widgets.
