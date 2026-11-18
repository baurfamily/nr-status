import Foundation
import Testing
@testable import NR_Status

struct ConfigurationYAMLTests {
    @Test func frontmatterParsesAndEditsWithoutChangingTheWorkbookBody() throws {
        let body = "# Overview\n\n```lua\nreturn { rows = { { count = 3 } } }\n```"
        var document = NRQL_EditorDocument(text: """
            ---
            author: "Example: team"
            description: |
              First line.
              ---
              Second line.
            api-key: "Production #1"
            accounts: [123, 456]
            bindings:
              - name: appName
                expression: '"Checkout"'
              - name: heading
                expression: config.appName .. " health"
            ---

            \(body)
            """)
        #expect(document.cells.map(\.kind) == [.config, .markdown, .lua])
        let connection = try document.connection.get()
        #expect(connection.apiKeyName == "Production #1")
        #expect(connection.accountIds == [123, 456])
        #expect(connection.variables.map(\.name) == ["appName", "heading"])
        #expect(NrqlCellSource.value("description", in: document.cells[0].configurationText).contains("---\n"))
        try document.setDefaultAccountIds([789])
        #expect(document.text.hasPrefix("---\n"))
        #expect(document.text.contains(body))
        #expect(document.cells[0].configurationText.contains("description: |\n"))
        #expect(NrqlCellSource.value("author", in: document.cells[0].configurationText) == "Example: team")
        #expect(try NRQL_EditorDocument(text: document.text).connection.get().accountIds == [789])
    }

    @Test func frontmatterDoesNotConsumeMarkdownRulesOrFencedExamples() throws {
        let document = NRQL_EditorDocument(text: """
            ---
            description: Example
            ...

            # Heading

            ---

            ```nrql
            SELECT 1
            ```

            ---
            Ordinary Markdown after a query.
            """)
        #expect(document.cells.map(\.kind) == [.config, .markdown, .nrql, .markdown])
        #expect(try document.connection.get() == NrqlConnection())
        let prose = NRQL_EditorDocument(text: "```text\n---\napi-key: Not configuration\n---\n```")
        #expect(prose.cells.map(\.kind) == [.markdown])
    }

    @Test(arguments: [
        "---\naccounts: [1, 2]\n",
        "---\naccounts: [1,\n---",
        "---\napi-key: One\napi_key: Two\n---",
        "---\nbindings: []\nbindings: []\n---",
        "---\n- not a mapping\n---"
    ])
    func invalidFrontmatterReportsErrorsWithoutFallback(_ text: String) {
        #expect(throws: (any Error).self) { try NRQL_EditorDocument(text: text).connection.get() }
    }

    @Test func yamlSequencesAndQuotedValuesApplyToCells() throws {
        let cell = NrqlCell(text: """
            ```cell_config
            title: "Requests: # by service"
            accounts:
              - 123
              - 456
            chart: line
            attributes: [lines, points]
            height: 12
            ```
            ```nrql
            SELECT count(*) FROM Transaction TIMESERIES
            ```
            """)
        #expect(cell.query.title == "Requests: # by service")
        #expect(try NrqlConnection.parse(cell.configurationText).accountIds == [123, 456])
        #expect(cell.query.format?.attributes == ["lines", "points"])
        #expect(cell.query.format?.heightInLines == 12)
    }

    @Test func graphqlSeparatesWholeResponseAndExtractionBindings() throws {
        var cell = NrqlCell(text: """
            ```cell_config
            var: 'response'
            bindings:
              - name: 'entity'
                expression: 'data.actor.entities[1]'
              - name: 'count'
                expression: '#data.actor.entities'
            chart: bindings
            ```
            ```graphql
            { actor { entities { name } } }
            ```
            """)
        let bindings = try NerdgraphCellSource(stored: cell.text).resultBindings()
        #expect(bindings.map(\.name) == ["response", "entity", "count"])
        #expect(bindings.last?.expression == "#data.actor.entities")
        try cell.addResultBinding(name: "firstName", expression: "data.actor.entities[1].name")
        #expect(try NerdgraphCellSource(stored: cell.text).resultBindings().count == 4)
        #expect(cell.configurationText.components(separatedBy: "var:").count == 2)
        #expect(try NrqlCellSource.resultName(in: cell.configurationText) == "response")
        #expect(NerdgraphCellSource(stored: cell.text).extractionBindings.map(\.name) == ["entity", "count", "firstName"])
    }

    @Test(arguments: [
        "var: [response]",
        "var: response = data.actor",
        "bindings: entity",
        "bindings: [entity]",
        "bindings: [{name: entity}]",
        "bindings: [{name: entity, expression: ''}]",
        "bindings: [{name: bad-name, expression: data}]",
        "bindings: [{name: entity, path: data}]",
        "var: response\nbindings: [{name: response, expression: data}]",
        "bindings: [{name: entity, expression: data}, {name: entity, expression: errors}]"
    ])
    func rejectsInvalidWholeResultOrExtractionConfiguration(_ configuration: String) {
        let source = NerdgraphCellSource(stored: "```cell_config\n\(configuration)\n```\n```graphql\n{}\n```")
        #expect(throws: (any Error).self) { try source.resultBindings() }
    }

    @Test func extractionsWorkWithoutAWholeResponseVariable() throws {
        let source = NerdgraphCellSource(stored: """
            ```cell_config
            bindings:
              - name: account
                expression: data.actor.account
            ```
            ```graphql
            { actor { user { name } } }
            ```
            """)
        #expect(try source.resultBindings() == [.init(name: "account", expression: "data.actor.account")])
        #expect(source.bindingNames == ["account"])
        #expect(source.format?.name == nil)
    }

    @Test func settingsEditsQuoteSpecialValuesAndPreserveUnrelatedYAML() throws {
        let original = """
            # A workbook note.
            title: Old
            future:
              nested: [one, two]
            description: |
              Keep this multiline text.
            attributes:
              - lines
              - points
            # Keep this comment too.
            """
        let updated = NrqlCellSource.updating("title", values: ["Report: # one"], in: original)
        let resized = NrqlCellSource.updating("attributes", values: ["points"], in: updated)
        #expect(try ConfigurationYAML(resized).value("title") == "Report: # one")
        #expect(try ConfigurationYAML(resized).values("attributes") == ["points"])
        #expect(resized.contains("future:\n  nested: [one, two]"))
        #expect(resized.contains("description: |\n  Keep this multiline text."))
        #expect(resized.contains("# A workbook note.") && resized.contains("# Keep this comment too."))
        #expect(!resized.contains("- lines") && !resized.contains("- points"))
    }

    @Test func connectionEditsPreserveDocumentVariablesAndComments() throws {
        var document = NRQL_EditorDocument(text: """
            ---
            # A workbook comment.
            description: "Report: by service"
            bindings:
              - name: appName
                expression: '"Checkout"'
              - name: threshold
                expression: 10
            accounts: 123, 456
            ---
            """)
        #expect(try document.connection.get().variables.count == 2)
        try document.setDefaultApiKey("Production")
        #expect(document.text.hasPrefix("---\n"))
        #expect(try ConfigurationYAML(document.cells[0].configurationText).mappings("bindings").count == 2)
        #expect(try document.connection.get().accountIds == [123, 456])
        #expect(document.text.contains("# A workbook comment."))
    }

    @Test func sampleWorkbooksUseStrictYAMLAndOfflineChartsStillRun() async throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        for filename in ["BusiestApp.nrmd", "ChartSamples.nrmd"] {
            let url = root.appendingPathComponent("docs/examples/\(filename)")
            let document = NRQL_EditorDocument(text: try String(contentsOf: url, encoding: .utf8))
            #expect(document.text.hasPrefix("---\n"))
            _ = try document.connection.get()
            for cell in document.cells {
                if cell.kind == .config || NrqlCellSource(stored: cell.text).configuration != nil {
                    _ = try ConfigurationYAML(cell.configurationText)
                }
                if cell.kind == .nerdgraph {
                    _ = try NerdgraphCellSource(stored: cell.text).resultBindings()
                }
                if filename == "ChartSamples.nrmd" && cell.kind == .lua {
                    await cell.query.getData()
                    #expect(cell.query.resultContainer != nil)
                }
            }
        }
    }
}
