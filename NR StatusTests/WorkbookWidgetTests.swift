import Foundation
import Testing
@testable import NR_Status

struct WorkbookWidgetTests {
    @MainActor private func run(_ widget: PublishedWidget, withProfile: Bool = true) async throws -> WorkbookWidgetOutput {
        let suite = "NR Status widget test \(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let profile = NerdgraphProfile(name: "Test", preferredAccountIds: [42])
        defaults.set(
            try JSONEncoder().encode(withProfile
                ? NerdgraphProfiles.Settings(profiles: [profile], defaultProfileID: profile.id)
                : NerdgraphProfiles.Settings()),
            forKey: "nerdgraphProfiles"
        )
        return try await WorkbookWidgetRunner.run(widget, profiles: NerdgraphProfiles(defaults: defaults))
    }

    private func publication(_ text: String, target: UUID, revision: UUID = UUID()) -> PublishedWidget {
        PublishedWidget(id: target, revision: revision, name: "Test Widget", sourceName: "Test.nrmd",
                        cellTitle: "Test", workbook: text, publishedAt: Date())
    }

    @Test func bulkPublishingUpdatesSnapshotsAndPreservesNamesAndIdentities() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let registry = WidgetRegistry(directory: directory)
        var document = NRQL_EditorDocument(text: """
            ```config
            description: Bulk publishing
            ```

            ```cell_config
            title: Count
            ```
            ```lua
            return { rows = { { count = 42 } } }
            ```

            # Notes

            Ready.
            """)
        let cellIDs = document.cells.filter(\.canPublishWidget).map(\.id)
        try WorkbookWidgetPublishing.publish(
            cellIDs: cellIDs, document: &document, sourceName: "Original.nrmd",
            names: [cellIDs[0]: "Custom widget name"], registry: registry
        )
        let ids = document.cells.compactMap(\.widgetID)
        #expect(ids.count == 2)
        let original = try #require(try registry.widget(id: ids[0]))
        #expect(original.name == "Custom widget name")
        #expect(original.workbook == document.text)
        #expect(try registry.widgets().allSatisfy {
            NRQL_EditorDocument(text: $0.workbook).cells.compactMap(\.widgetID) == ids
        })
        try registry.cache(WorkbookWidgetOutput(title: "Cached", updatedAt: Date()), for: original)
        document.cells[1].editorText = "return { rows = { { count = 84 } } }"
        try WorkbookWidgetPublishing.publish(
            cellIDs: cellIDs, document: &document, sourceName: "Renamed.nrmd", registry: registry
        )
        let updated = try #require(try registry.widget(id: ids[0]))
        #expect(document.cells.compactMap(\.widgetID) == ids)
        #expect(updated.name == original.name)
        #expect(updated.sourceName == "Renamed.nrmd")
        #expect(updated.revision != original.revision)
        #expect(updated.workbook == document.text)
        #expect(updated.workbook.contains("count = 84"))
        #expect(try registry.widgets().count == 2)
        #expect(try registry.cachedOutput(for: original) == nil)
    }

    @Test func unpublishingRemovesTheSnapshotAndCacheButAllowsReconnecting() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let registry = WidgetRegistry(directory: directory)
        var document = NRQL_EditorDocument(text: "# Ready")
        let cellID = document.cells[0].id
        try WorkbookWidgetPublishing.publish(
            cellIDs: [cellID], document: &document, sourceName: "Test.nrmd", registry: registry
        )
        let id = try #require(document.cells[0].widgetID)
        let original = try #require(try registry.widget(id: id))
        try registry.cache(WorkbookWidgetOutput(title: "Ready", updatedAt: Date(), markdown: "# Ready"), for: original)
        try WorkbookWidgetPublishing.unpublish(cellID: cellID, document: document, registry: registry)
        #expect(try registry.widget(id: id) == nil)
        #expect(try registry.cachedOutput(for: original) == nil)
        #expect(document.cells[0].widgetID == id)
        try WorkbookWidgetPublishing.unpublish(cellID: cellID, document: document, registry: registry)
        try WorkbookWidgetPublishing.publish(
            cellIDs: [cellID], document: &document, sourceName: "Test.nrmd", registry: registry
        )
        #expect(try registry.widget(id: id) != nil)
        #expect(try registry.widgets().count == 1)
    }

    @Test(arguments: [false, true])
    func bulkValidationDoesNotPublishOrMutateAnyCells(duplicateIdentity: Bool) throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let registry = WidgetRegistry(directory: directory)
        let metadata = duplicateIdentity ? "```cell_config\nwidget-id: \(UUID())\n```\n" : ""
        var document = NRQL_EditorDocument(text: """
            \(metadata)```lua
            return { rows = { { count = 42 } } }
            ```

            \(metadata)```lua
            \(duplicateIdentity ? "return { rows = { { count = 84 } } }" : "return results.missing")
            ```
            """)
        let original = document.text
        let cellIDs = document.cells.map(\.id)
        #expect(throws: NrqlConnection.ConfigurationError.self) {
            try WorkbookWidgetPublishing.publish(
                cellIDs: cellIDs, document: &document, sourceName: "Test.nrmd", registry: registry
            )
        }
        #expect(try registry.widgets().isEmpty)
        #expect(document.text == original)
        #expect(document.cells.allSatisfy { $0.query.text == $0.text })
    }

    @Test func publicationsAreGroupedAndNaturallySortedByFileThenCell() {
        func widget(_ name: String, file: String) -> PublishedWidget {
            PublishedWidget(id: UUID(), revision: UUID(), name: name, sourceName: file,
                            cellTitle: name, workbook: "", publishedAt: Date())
        }
        let groups = PublishedWidgetGroup.grouping([
            widget("Chart 1", file: "Workbook 10.nrmd"),
            widget("Chart 10", file: "Workbook 2.nrmd"),
            widget("Chart 2", file: "Workbook 2.nrmd")
        ])
        #expect(groups.map(\.sourceName) == ["Workbook 2.nrmd", "Workbook 10.nrmd"])
        #expect(groups[0].widgets.map(\.name) == ["Chart 2", "Chart 10"])
        #expect(groups[1].widgets.map(\.name) == ["Chart 1"])
    }

    @MainActor @Test func chartSampleWorkbookRunsEveryChartDeterministicallyWithoutCredentials() async throws {
        let url = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("docs/examples/ChartSamples.nrmd")
        var document = NRQL_EditorDocument(text: try String(contentsOf: url, encoding: .utf8))
        let charts = document.cells.filter(\.canPublishWidget)
        #expect(charts.count == ChartType.allCases.count)
        #expect(Set(charts.compactMap { $0.query.format?.type }) == Set(ChartType.allCases))
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let registry = WidgetRegistry(directory: directory)
        try WorkbookWidgetPublishing.publish(
            cellIDs: charts.map(\.id), document: &document, sourceName: "ChartSamples.nrmd", registry: registry
        )
        for widget in try registry.widgets() {
            let first = try await run(widget, withProfile: false)
            let second = try await run(widget, withProfile: false)
            #expect(first.chart == second.chart)
            let results = try #require(first.resultContainer)
            #expect(!results.data.isEmpty)
            let configuration = ChartConfiguration(resultContainer: results)
            let format = ChartFormat.parseMetadata(try #require(first.configuration))
            format.apply(to: configuration)
            #expect(configuration.chartType == format.type)
        }
    }

    @MainActor @Test func sharedRegistryPersistsPublishedWorkbooks() async throws {
        let id = UUID()
        var widget = publication("```cell_config\nwidget-id: \(id)\n```\n# Ready", target: id)
        widget.name = "Widget picker test \(id)"
        let registry = try WidgetRegistry.shared()
        try registry.save(widget)
        defer { try? registry.remove(widget) }

        let reader = try WidgetRegistry.shared()
        let resolved = try #require(try reader.widget(id: id))
        #expect(resolved.name == widget.name)
        #expect(resolved.sourceName == widget.sourceName)
        #expect(try reader.widgets().contains { $0.id == id })

        let output = try await run(widget)
        try registry.cache(output, for: widget)
        #expect(try registry.cachedOutput(for: widget)?.markdown == "# Ready")
        try registry.remove(widget)
        #expect(try reader.widget(id: id) == nil)
    }

    @Test func markdownIdentitySurvivesSavingMovingRenamingAndDuplicating() throws {
        let id = UUID()
        var document = NRQL_EditorDocument(text: """
            ```lua
            return { rows = { { count = 1 } } }
            ```

            ```cell_config
            widget-id: \(id)
            ```
            # Original

            Count: {{ results.count.rows[1].count }}
            """)
        #expect(document.cells.count == 2)
        let cell = document.cells[1]
        #expect(cell.kind == .markdown)
        #expect(cell.editorText.hasPrefix("# Original"))
        #expect(!cell.editorText.contains("widget-id"))
        document.cells[1].editorText = "# Renamed\n\nSome text."
        document.perform(.moveUp, on: cell.id)
        let reopened = NRQL_EditorDocument(text: document.text)
        #expect(reopened.cells[0].widgetID == id)
        #expect(reopened.cells[0].query.title == "Renamed")
        document.perform(.duplicate, on: cell.id)
        #expect(document.cells.filter { $0.widgetID == id }.count == 1)
        #expect(document.cells[1].widgetID == nil)
        #expect(document.cells[1].editorText == document.cells[0].editorText)
        #expect(NRQL_EditorDocument(text: document.text).cells.count == 3)
    }

    @MainActor @Test func runsOnlyTransitiveDependenciesAndExpandsMarkdown() async throws {
        let id = UUID()
        let text = """
            ```config
            api-key: Test
            accounts: 7
            var multiplier = 2
            ```

            ```cell_config
            var: unused
            ```
            ```lua
            error("Must not run")
            ```

            ```cell_config
            widget-id: \(id)
            ```
            # Active

            Count: {{ results[ "derived" ].rows[1].count }} / Account: {{ config.accounts[1] }}

            ```cell_config
            var: derived
            ```
            ```lua
            return { rows = { { count = results.base.rows[1].count * config.multiplier } } }
            ```

            ```cell_config
            var: base
            ```
            ```lua
            return { rows = { { count = 21 } } }
            ```
            """
        let output = try await run(publication(text, target: id))
        #expect(output.markdown == "# Active\n\nCount: 42 / Account: 7")
        #expect(output.chart == nil)
    }

    @MainActor @Test func chartConfigurationAndResultsSurviveCaching() async throws {
        let id = UUID()
        let widget = publication("""
            ```cell_config
            widget-id: \(id)
            title: Count
            chart: billboard
            attributes: gauge, max(100)
            ```
            ```lua
            return { rows = { { count = 42 } } }
            ```
            """, target: id)
        let output = try await run(widget)
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let registry = WidgetRegistry(directory: directory)
        try registry.save(widget)
        try registry.cache(output, for: widget)
        let cached = try #require(try registry.cachedOutput(for: widget))
        #expect(cached.resultContainer?.data.first?.numberFields["count"] == 42)
        #expect(ChartFormat.parseMetadata(cached.configuration ?? "").type == .billboard)
        #expect(cached.configuration?.contains("max(100)") == true)
        #expect(cached.updatedAt == output.updatedAt)
        let replacement = publication(widget.workbook, target: id)
        try registry.save(replacement)
        try registry.cache(output, for: widget)
        #expect(try registry.cachedOutput(for: replacement) == nil)
        #expect(try registry.cachedOutput(for: widget) == nil)
        try registry.remove(replacement)
        #expect(try registry.widgets().isEmpty)
    }

    @MainActor @Test func dependencyFailuresAreReportedWithoutPartialOutput() async throws {
        let id = UUID()
        let widget = publication("""
            ```cell_config
            var: broken
            ```
            ```lua
            error("upstream failed")
            ```

            ```cell_config
            widget-id: \(id)
            ```
            # {{ results.broken.rows[1].count }}
            """, target: id)
        do {
            _ = try await run(widget)
            Issue.record("A failed dependency must fail the widget refresh.")
        } catch {
            #expect(error.localizedDescription.contains("upstream failed"))
        }
    }

    @Test(arguments: [
        "return results.missing",
        "return results[1]",
        "return results[\"missing\" .. \"Suffix\"]",
        "return results",
        "return results.loop"
    ])
    func rejectsMissingDynamicAndCyclicDependencies(script: String) {
        let document = NRQL_EditorDocument(text: """
            ```cell_config
            var: loop
            ```
            ```lua
            \(script)
            ```
            """)
        #expect(throws: NrqlConnection.ConfigurationError.self) {
            try WorkbookWidgetRunner.plan(target: document.cells[0], in: document.cells)
        }
    }

    @Test func rejectsAmbiguousDependenciesAndBackgroundMutations() {
        for source in [
            "```cell_config\nvar: shared\n```\n```lua\nreturn {}\n```\n\n```cell_config\nvar: shared\n```\n```lua\nreturn {}\n```",
            "```cell_config\nvar: shared\n```\n```graphql\nmutation { example }\n```"
        ] {
            let document = NRQL_EditorDocument(text: source + "\n\n# {{ results.shared }}")
            #expect(throws: NrqlConnection.ConfigurationError.self) {
                try WorkbookWidgetRunner.plan(target: document.cells.last!, in: document.cells)
            }
        }
    }
}
