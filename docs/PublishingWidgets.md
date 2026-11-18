# Publishing desktop widgets

[Documentation](README.md)

Publish a chart, Lua console, or Markdown cell from a workbook, then select that publication
in a macOS **Workbook** widget.

## Publish one cell

1. Save your workbook so the publication can record its source location.
2. Open the cell's menu and choose **Publish as Widget…**.
3. Give it a name and confirm. Save the workbook again to retain its widget identity.
4. Open macOS **Edit Widgets**, add a **Workbook** widget, then use **Edit Widget**
   to choose the publication.

The widget picker and **Features > Published Widgets** group publications by
source filename. Try [ChartSamples.nrmd](examples/ChartSamples.nrmd) for charts
that need neither an API key nor network access.

## Update and remove

Editing or saving source does **not** automatically update its publication.
Use **Update Published Widget…** in the cell menu, or **Update Widget** in its
configuration sidebar, to publish the current snapshot.

Use **Unpublish Widget** to remove a publication. Republishing the same cell
reconnects existing widgets when its saved identity is retained.

The **Document Config** cell's menu also offers:

| Action | Scope |
|---|---|
| Publish All Widgets… | Publish all eligible chart/console/Markdown cells or update existing publications; preserves custom names |
| Update All Widgets | Update only cells already published from this workbook |
| Unpublish All Widgets… | Remove this workbook's publications after confirmation |

Bulk actions do not affect other workbooks.

## What gets published

Publishing stores a snapshot of the **entire workbook** in the shared App Group,
not a live link to its text file. Treat that snapshot as another local copy of
your workbook and its contents. API key secrets remain in Keychain; saved key
names are resolved there during execution.

The widget extension reruns the chosen cell and its transitive dependencies
without needing the app open. Dependencies must use named references:
`results.name` or `results["name"]`. Positional/computed references,
missing/ambiguous dependencies, cycles, and GraphQL mutations/subscriptions
are rejected.

Refresh is requested after five minutes, subject to macOS WidgetKit scheduling;
it is not a guaranteed polling interval. Failed refreshes keep the last
successful output and mark it stale.

Small/medium widgets simplify axes and legends to fit. Large widgets retain
nonredundant legends when they fit in two lines. Tables show a static grid and
a remaining-row count; billboards fit their tiles to the available area.
Lua consoles show plain monospaced text, clipped to the widget's available space.

## Open or recover the source

Click a configured widget to open its workbook and reveal the published cell.
File bookmarks can follow moves and renames. Publications created before source
navigation was supported need to be updated once to record their location.

If the workbook or cell cannot be found, **Recover Workbook…** saves and opens
a copy of the published snapshot, including its configuration and dependencies.
It cannot recover edits made after publication. Unpublishing removes the
recovery snapshot too.

Publishing an unsaved workbook is allowed, but save and update the publication
to record its location and retain the cell's `widget-id`.

## If a widget will not configure

Old chart-specific widgets are not migrated. Remove them and add a **Workbook**
widget. For development builds, signing, or a missing **Edit Widget** action,
see [development troubleshooting](Development.md); do not delete system widget caches.
