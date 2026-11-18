# Screenshot capture guide

[Documentation](README.md)

The README needs current screenshots rather than the old editor image.
Automated capture was unavailable during this documentation refresh: the
terminal process did not have macOS Screen Recording permission, and no
NR Status window was open. No replacement images have been captured.

## Set up a safe demo

1. Launch the current NR Status build and open
   [`examples/ChartSamples.nrmd`](examples/ChartSamples.nrmd).
2. Choose **Run All**. This workbook uses deterministic Lua data, so no API
   key, account, or network setup is needed.
3. Use a clean window with a consistent appearance and readable text. Collapse
   code when showing charts; expand one short cell for an editor shot.
4. For widgets, save a **copy** of the sample workbook, publish a few cells,
   save again, and add/configure Workbook widgets on a clean desktop.

Use the copy for publishing so documentation work does not change the
checked-in sample's widget identities.

## Short shot list

| File under `docs/images/` | Show |
|---|---|
| `workbook.png` | A readable code cell and two contrasting charts; README hero |
| `cell-configuration.png` | A chart with its Settings sidebar open; configuration guide |
| `desktop-widgets.png` | Two or three configured Workbook widgets; publishing guide |
| `graphql-bindings.png` | Optional sanitized GraphQL response and extracted bindings |

The offline sample covers the first three. For GraphQL, use a demo account,
configure a user API key in Settings, and run a query that returns only
non-sensitive data. Do not expose keys, customer data, personal account names,
private paths, or unrelated desktop windows.

## Capture

Use **Shift-Command-5 > Capture Selected Window** (or a tightly selected
desktop region for widgets). Avoid a full-desktop capture containing other apps.
Review the image before adding it.

For terminal-driven captures, enable the terminal/automation host in
**System Settings > Privacy & Security > Screen & System Audio Recording**
(the exact label varies by macOS release), then restart that host if prompted.
GUI automation may also need Accessibility permission. Grant permissions only
to the host you intend to use.

Once captured, add the images under `docs/images/`, embed the workbook image
in the README and the detailed shots in the relevant guides, with meaningful
alt text. Keep the README to one strong overview image.
