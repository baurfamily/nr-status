import Foundation
import Testing
@testable import NR_Status

struct WorkbookWidgetTests {
    @MainActor private func run(_ widget: PublishedWidget) async throws -> WorkbookWidgetOutput {
        let suite = "NR Status widget test \(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let profile = NerdgraphProfile(name: "Test", preferredAccountIds: [42])
        defaults.set(
            try JSONEncoder().encode(NerdgraphProfiles.Settings(profiles: [profile], defaultProfileID: profile.id)),
            forKey: "nerdgraphProfiles"
        )
        return try await WorkbookWidgetRunner.run(widget, profiles: NerdgraphProfiles(defaults: defaults))
    }

    private func publication(_ text: String, target: UUID, revision: UUID = UUID()) -> PublishedWidget {
        PublishedWidget(id: target, revision: revision, name: "Test Widget", sourceName: "Test.nrmd",
                        cellTitle: "Test", workbook: text, publishedAt: Date())
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
