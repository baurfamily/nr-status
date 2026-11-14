# Refactoring Status & TODO (NR Status)

## Done

- [x] **Networking:** `NerdgraphClient` and `Queries` collapsed into one async client with `NerdgraphConfig` and `GraphQLDocuments`. Errors are thrown, and the HTTP status and GraphQL `errors` are checked.
- [x] **NRDB decoding:** hardened `Datum` decoding and the date helpers. `Datum.date` is now optional, and charts skip points without a date. Covered by `NrdbTests`.
- [x] **`NrqlQuery` / `NRQL_EditorDocument`:** `State` enum (idle / running / loaded / failed), `NrqlDocumentParser` with tests, and the callback API removed.
- [x] **Chart dispatch:** `ConfigurableChartView` uses a `switch`.
- [x] **Widgets:** one generic provider, entry and view in `NrqlChartWidgetSupport.swift`. Each widget is about 30 lines.
- [x] **Widget config workaround:** host, key and account IDs come from Preferences via an App Group (see the Edit Widget item below).
- [x] **`xcodebuild test` works:** the `NR Status` scheme no longer pulls in the vestigial framework, and `NR StatusTests` depends on the app.
- [x] **Placeholder UTType:** replaced with the exported NR Markdown type `net.baurhome.nrmd` (`.nrmd`).
- [x] **Debug `print`s** removed from `PreferencesView` and `AttributeListView`. `ChartSamples` uses `os.Logger`.
- [x] **Force unwraps and unguarded indexing** replaced in `AttributeSummary`, `NRQL_EditorDocument`, `PieChart`, `BillboardChart`, `BarChart` and `TimeseriesChart`.
- [x] **`AttributeListItemView`:** extracted `RemovablePill` and binding helpers, and removed dead code and the double-wrapped `.task`.
- [x] **`AttributeSummaryView`:** removed commented-out code.
- [x] **`QueryBuilder`:** typed `TimeWindowChoice`, `ResultLimit` and `TimeseriesSize`; removed the unsettable `AggregateFunction` fields; `choices` are `static let`; shared key-matching helpers; `TimePicker` binds directly.
- [x] **Timeseries chart redraw:** style toggles (Smoothed, Lines, Points, Stacked) now apply immediately.
- [x] **Credentials:** the host and API key are one keychain credential (internet password: server = host, data = key), shared with the widget via an access group. Account IDs stay in the App Group defaults. There is no migration code, since the app is unpublished; the key is entered once in Preferences.
- [x] **Tests:** `QueryBuilderTests` covers `QueryBuilder.nrql`, and `KeychainStoreTests` covers a real-keychain round trip.

## TODO

- [ ] **Edit Widget does nothing.** "Edit Widget…" does nothing for our widgets, even for a build of `45df6aa` (when it worked), so it is likely environmental (macOS/Xcode 27 or dev-signed registration). Find the root cause, then restore per-widget query and chart options (the intent `apiHost`/`apiKey`/`accountIds` parameters are currently ignored).
- [ ] **Shared `NR Models` framework.** The app and widget each compile the `NR Models/` sources directly, so everything is built twice into separate modules (including the `ChartType` and `GaugeStyle` AppEnums, a possible registry conflict). Either make `NR Models` a real framework (needs `public` access and project-file work), or delete the unused `NR Models` and `NR ModelsTests` targets.
- [ ] **Verify on screen:** opening a `.nrmd` file with the new UTType, and the widgets' data flow (keychain access group and App Group defaults). Also check that Preferences shows the saved key, and build and sign the Release configuration, which has not been built.
- [ ] **Time picker:** check the Time window, Interval and Limit pickers after the `QueryBuilder` change. A timeseries with no interval chosen now emits `TIMESERIES AUTO` (it used to emit `TIMESERIES ` with nothing after it).
- [ ] **Injection:** account IDs and the domain are interpolated into NRQL/GraphQL. Validate them (integers only) or pass them as variables.
- [ ] **Move the `entitySearch` query** to a `.graphql` resource or a dedicated file.
- [ ] **Remaining `print` calls.** Replace any that are left with `os.Logger`.
- [ ] **`ConfigurableChartView`** copies its config into `@State`. Review whether it should hold the model directly.
- [ ] **Stale `INIntentsSupported`** = `ConfigurationAppIntent` in the app's `Info.plist`.
- [ ] **Tests:** more coverage for `NrdbResultContainer` edge cases (empty results, comparisons).
- [ ] **Preferences saves on every keystroke,** which rewrites the keychain item each time. Save on submit instead (optional).
- [ ] **Parser stages (optional):** a tokenizer and clause splitter for `NrqlDocumentParser`, only if features need them.

## Notes

- Run tests without touching Xcode's DerivedData: `xcodebuild test -scheme "NR Status" -destination 'platform=macOS' -derivedDataPath /tmp/x -only-testing:"NR StatusTests"`, then `rm -rf /tmp/x`. Running against the shared DerivedData leaves unsigned `.xctest` bundles in the app's `PlugIns`, which makes the next Xcode build fail with a CodeSign error.
