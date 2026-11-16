//
//  NrqlDocumentTests.swift
//  NR StatusTests
//

import Testing
import Foundation
import CoreGraphics
import PDFKit
import AppKit
@testable import NR_Status

struct CellConfigurationTests {
    @MainActor @Test func resizingPersistsWithoutDiscardingResultsOrOtherSettings() throws {
        var cell = NrqlCell(text: """
            ```cell_config
            title: Busiest app
            var: apps
            attributes: gauge, max(100)
            future: preserved
            ```
            ```lua
            return { rows = { { count = 50 } } }
            ```
            """)
        let results = try JSONDecoder().decode(NrdbResultContainer.self, from: Data(
            #"{"nrql":"","results":[{"count":50}],"metadata":{}}"#.utf8
        ))
        cell.query.setState(.loaded(results))
        let code = cell.editorText
        cell.setChartHeight(30)
        #expect(cell.query.format?.heightInLines == 30)
        #expect(cell.query.resultContainer?.data.first?.numberFields["count"] == 50)
        #expect(cell.editorText == code)
        #expect(cell.configurationText.contains("future: preserved"))
        #expect(cell.query.format?.attributes == ["gauge", "max(100)"])
        #expect(NRQL_EditorDocument(text: cell.text).cells[0].query.format?.heightInLines == 30)
        cell.setChartHeight(nil)
        #expect(cell.query.format?.heightInLines == nil)
        #expect(!cell.configurationText.contains("height:"))
        #expect(cell.query.title == "Busiest app")
        #expect(cell.query.resultNames == ["apps"])
        #expect(cell.query.resultContainer != nil)
    }

    @Test(arguments: [
        (NrqlCellKind.nrql, "SELECT count(*) FROM Transaction"),
        (.lua, "return { rows = { { count = 5 } } }")
    ])
    func chartHeightEditsRoundTripWithoutChangingCode(kind: NrqlCellKind, code: String) {
        var document = NRQL_EditorDocument(text: kind.wrap(code))
        document.cells[0].configurationText = "chart: billboard\nheight: 30"
        let reopened = NRQL_EditorDocument(text: document.text)
        #expect(reopened.cells[0].editorText == code)
        #expect(reopened.cells[0].query.format?.heightInLines == 30)
        document.cells[0].configurationText = NrqlCellSource.updating(
            "height", values: [], in: document.cells[0].configurationText
        )
        #expect(document.cells[0].query.format?.heightInLines == nil)
        #expect(document.cells[0].query.format?.type == .billboard)
    }

    @Test(arguments: [
        (NrqlCellKind.nrql, "SELECT 1"),
        (.lua, "return { rows = {} }"),
        (.nerdgraph, "{ actor { user { name } } }")
    ])
    func queryVisibilityIsAnOpeningDefaultNotLiveCollapseState(kind: NrqlCellKind, code: String) {
        let text = "```cell_config\nquery: hide\n```\n" + kind.wrap(code)
        var document = NRQL_EditorDocument(text: text)
        #expect(document.cells[0].isCollapsed)
        #expect(document.cells[0].isRunnable)

        document.cells[0].isCollapsed = false
        #expect(document.text == text + "\n")
        #expect(document.cells[0].query.format?.hidesQuery == true)
        #expect(NRQL_EditorDocument(text: document.text).cells[0].isCollapsed)

        document.cells[0].configurationText = "query: show"
        #expect(!document.cells[0].isCollapsed)
        document.cells[0].isCollapsed = true
        #expect(!NRQL_EditorDocument(text: document.text).cells[0].isCollapsed)
        document.cells[0].configurationText = "query: hide"
        #expect(document.cells[0].isCollapsed)
        document.cells[0].isCollapsed = false
        document.cells[0].configurationText = "query: hide\ntitle: Changed"
        #expect(!document.cells[0].isCollapsed)
        #expect(document.cells[0].editorText == code)
    }

    @Test(arguments: [
        ("", false),
        ("query: show", false),
        ("  Query: HIDE  ", true),
        ("query: unknown", false)
    ])
    func queryVisibilityDefaultsToShown(configuration: String, hidden: Bool) {
        let cell = NrqlCell(text: "```cell_config\n\(configuration)\n```\n```lua\nreturn {}\n```")
        #expect(cell.isCollapsed == hidden)
        #expect(cell.query.format?.hidesQuery == hidden)
    }

    @Test func configTravelsWithCodeAndVariablesAndEditsRoundTrip() throws {
        var document = NRQL_EditorDocument(text: """
            ```config
            author: Ada
            ```

            ```cell_config
            title: Entities
            var: entities = data.actor.entities
            future: preserved
            ```

            ```graphql
            { actor { user { name } } }
            ```
            ```variables
            {"id": 42}
            ```

            ```nrql
            SELECT 1
            ```
            """)
        #expect(document.cells.map(\.kind) == [.config, .nerdgraph, .nrql])
        #expect(document.cells[0].isCollapsed)
        let id = document.cells[1].id
        let originalCode = document.cells[1].editorText
        document.cells[1].configurationText = NrqlCellSource.updating(
            "title", values: ["Updated: entities"], in: document.cells[1].configurationText
        )
        #expect(document.cells[1].editorText == originalCode)
        #expect(document.cells[1].query.title == "Updated: entities")
        #expect(document.cells[1].configurationText.contains("future: preserved"))
        document.cells[1].editorText = originalCode.replacingOccurrences(of: "name", with: "email")
        #expect(document.cells[1].query.variables == #"{"id": 42}"#)
        document.perform(.moveDown, on: id)
        #expect(document.cells[2].query.title == "Updated: entities")
        let reopened = NRQL_EditorDocument(text: document.text)
        #expect(reopened.text == document.text)
        #expect(reopened.cells[2].query.resultNames == ["entities"])
        #expect(reopened.cells[2].query.nrql.contains("email"))
    }

    @Test(arguments: [
        (NrqlCellKind.nrql, "// Comment title\nSELECT 1", "NRQL Query"),
        (.lua, "-- Comment title\nreturn { rows = {} }", "Lua Script"),
        (.nerdgraph, "# Comment title\n{ actor { user { name } } }", "Nerdgraph Query")
    ])
    func firstLineTitleRequiresNoCellConfiguration(kind: NrqlCellKind, code: String, fallback: String) {
        var cell = NrqlCell(text: kind.wrap(code))
        #expect(cell.query.title == "Comment title")
        cell.configurationText = ""
        #expect(cell.query.title == fallback)
        cell.configurationText = "var: result"
        #expect(cell.query.title == fallback)
        cell.configurationText = "title: Explicit"
        #expect(cell.query.title == "Explicit")
        cell.removeConfiguration()
        #expect(cell.query.title == "Comment title")
        #expect(cell.editorText == code)
        #expect(NrqlCell(text: kind.wrap("\n" + code)).query.title == fallback)
    }

    @Test func adjacentConfiguredCellsStaySeparateAndProseFencesStayLiteral() {
        let first = "```cell_config\ntitle: One\n```\n```nrql\nSELECT 1\n```"
        let second = "```cell_config\ntitle: Two\n```\n```lua\nreturn {}\n```"
        let prose = "```text\n```cell_config\nliteral\n```"
        let document = NRQL_EditorDocument(text: first + "\n\n" + second + "\n\n" + prose)
        #expect(document.cells.map(\.kind) == [.nrql, .lua, .markdown])
        #expect(document.cells.map(\.query.title) == ["One", "Two", "Markdown"])
        #expect(document.cells.last?.text == prose)
    }

    @Test func editingBindingsPreservesNewlinesWhileTyping() {
        let configuration = NrqlCellSource.updating("var", values: ["response", ""], in: "", includeEmptyValues: true)
        #expect(NrqlCellSource.values("var", in: configuration).joined(separator: "\n") == "response\n")
        let edited = NrqlCellSource.updating(
            "var", values: ["response", "entity = data.actor.entity"], in: configuration, includeEmptyValues: true
        )
        #expect(NrqlCellSource.values("var", in: edited) == ["response", "entity = data.actor.entity"])
        #expect(!edited.contains("var: \n"))
    }
}

struct NrqlDocumentParserTests {
    @Test func graphqlAndVariablesFormOneCellAndRoundTrip() {
        let text = """
        # Notes

        ```cell_config
        var: user
        ```
        ```graphql
        query { actor { user { name } } }
        ```
        ```variables
        {"id": {{ results.ids.rows[1].id }}}
        ```

        ```lua
        return { rows = { { name = results.user.data.actor.user.name } } }
        ```
        """
        let document = NRQL_EditorDocument(text: text)
        #expect(document.cells.map(\.kind) == [.markdown, .nerdgraph, .lua])
        let cell = document.cells[1]
        #expect(cell.isRunnable)
        #expect(cell.query.name == "user")
        #expect(cell.query.nrql.contains("query { actor"))
        #expect(!cell.query.nrql.contains("```variables"))
        #expect(cell.query.variables == #"{"id": {{ results.ids.rows[1].id }}}"#)
        #expect(cell.storedText(forEditorText: cell.editorText) == cell.text)
        #expect(NRQL_EditorDocument(text: document.text).text == document.text)
    }

    @Test func optionalAndUnclosedVariablesStayWithGraphql() {
        let query = "```graphql\n{ actor { user { name } } }\n```"
        let document = NRQL_EditorDocument(text: query + "\n\n```variables\n{}")
        #expect(document.cells.count == 1)
        #expect(!NerdgraphCellSource(stored: document.cells[0].text).isClosed)
        #expect(NerdgraphCellSource(stored: query).variables == "{}")
        #expect(NrqlDocumentParser.blocks("```text\n```graphql\nliteral\n```").count == 1)
        #expect(NrqlCellKind.detect(in: "```nerdgraph\n{}\n```") == .nerdgraph)
    }

    @Test func graphqlOperationKeepsCommentsAndStringsLiteral() {
        let query = #"query { search(query: "/*** name: notMetadata ***/ {{ results.nope }}") { count } }"#
        let cell = NrqlCell(text: NrqlCellKind.nerdgraph.wrap(query))
        #expect(cell.query.nrql == query)
        #expect(cell.query.name == nil)
        #expect(NrqlDependencies.referencedNames(by: cell).isEmpty)
    }

    @Test func parsesQueryWithoutTrailingBlankLine() {
        let text = "// Title\nSELECT count(*) FROM A"
        let queries = NrqlDocumentParser.parse(text)

        #expect(queries.count == 1)
        #expect(queries[0].text == text)
        #expect(queries[0].range.location == 9)
    }

    @Test func queryAtOffsetZeroKeepsItsStart() {
        // used to be re-assigned to the start of the last line
        let queries = NrqlDocumentParser.parse("SELECT count(*)\nFROM A\n\n")

        #expect(queries.count == 1)
        #expect(queries[0].range.location == 0)
    }

    @Test func splitsOnBlankLines() {
        let text = "// One\nSELECT 1\n\n// Two\nSELECT 2\nFROM B\n\nSELECT 3"
        let queries = NrqlDocumentParser.parse(text)

        #expect(queries.map(\.text) == ["// One\nSELECT 1", "// Two\nSELECT 2\nFROM B", "SELECT 3"])
        #expect(queries[1].range.location == (text as NSString).range(of: "SELECT 2").location)
    }

    @Test func commentOnlyBlocksAreNotQueries() {
        #expect(NrqlDocumentParser.parse("// just a note\n\nSELECT 1").count == 1)
    }

    @Test func offsetsAreUtf16() {
        let text = "SELECT 'é😀'\n\nSELECT 2"
        let queries = NrqlDocumentParser.parse(text)

        #expect(queries[1].range.location == (text as NSString).range(of: "SELECT 2").location)
    }

    @Test func emptyTextHasNoQueries() {
        #expect(NrqlDocumentParser.parse("").isEmpty)
    }

    @Test func blocksSplitMarkdownAndFencedCode() {
        let text = "# Notes\n\nSome text\n\n```nrql\nSELECT 1\n\nFROM A\n```\n```lua\nemit({})\n```\nAfter\n"
        let blocks = NrqlDocumentParser.blocks(text)

        #expect(blocks == [
            "# Notes\n\nSome text",
            "```nrql\nSELECT 1\n\nFROM A\n```",
            "```lua\nemit({})\n```",
            "After",
        ])
        #expect(NrqlDocumentParser.blocks(NrqlDocumentParser.join(blocks)) == blocks)
    }

    @Test func otherFencesStayMarkdown() {
        let text = "Intro\n\n```swift\n```nrql\nnot a cell\n```\n\nOutro"
        let blocks = NrqlDocumentParser.blocks(text)

        #expect(blocks.count == 1)
        #expect(blocks[0] == text)
    }

    @Test func joinSkipsEmptyBlocks() {
        #expect(NrqlDocumentParser.join(["A", "", "  \n", "B"]) == "A\n\nB\n")
    }
}

@MainActor
struct NerdgraphCellTests {
    @Test func jsonAndNoneDisplayModesPreserveLoadedNRQLBindings() throws {
        let container = try JSONDecoder().decode(NrdbResultContainer.self, from: Data("""
            {"nrql":"SELECT 7", "results":[{"count":7,"name":"Foo","values":[1,2]}],
             "metadata":{"facets":null,"timeWindow":null}}
            """.utf8))
        let cell = NrqlCell(text: "```cell_config\nvar: source\nchart: json\n```\n```nrql\nSELECT 7\n```")
        let query = cell.query
        query.setState(.loaded(container))
        let json = try #require(query.displayedJSON).get()
        #expect(json == .array([.object([
            "count": .number(7), "name": .string("Foo"), "values": .array([.number(1), .number(2)])
        ])]))
        #expect(query.namedResults.first?.name == "source")
        #expect(NrqlExport.tableData(for: cell) == nil)
        var document = NRQL_EditorDocument()
        document.cells = [cell]
        let html = NrqlExport.html(for: document)
        #expect(html.contains(try json.encodedText(pretty: true)))
        #expect(!html.contains("\"rows\"") && !html.contains("\"columns\""))
        #expect(!html.contains("data:image/png"))
        query.text = query.text.replacingOccurrences(of: "chart: json", with: "chart: none")
        #expect(query.displayedJSON == nil)
        #expect(query.hasResult)
        #expect(query.namedResults.first?.name == "source")
        #expect(query.resultContainer?.data.first?.numberFields["count"] == 7)
        query.text = query.text.replacingOccurrences(of: "chart: none", with: "chart: json")
        #expect(try #require(query.displayedJSON).get() == json)
    }

    @Test func emptyNRQLJSONDisplaysAnEmptyArray() throws {
        let container = try JSONDecoder().decode(NrdbResultContainer.self, from: Data("""
            {"nrql":"SELECT name FROM Transaction", "results":[],
             "metadata":{"facets":null,"timeWindow":null}}
            """.utf8))
        let query = NrqlQuery(from: "```cell_config\nchart: json\n```\n```nrql\nSELECT name FROM Transaction\n```")
        query.setState(.loaded(container))
        #expect(try #require(query.displayedJSON).get() == .array([]))
    }

    @Test func hiddenNerdgraphResultsKeepBindingsAndExposeErrors() throws {
        let query = NrqlQuery(from: "```cell_config\nvar: response\n```\n```graphql\n{ actor { user { name } } }\n```")
        let value = JSONValue.object(["data": .object(["name": .string("Foo")])])
        query.setState(.jsonLoaded(value))
        #expect(try #require(query.displayedJSON).get() == value)
        query.text = query.text.replacingOccurrences(of: "var: response", with: "var: response\nchart: none")
        #expect(!query.showsResultPane)
        #expect(query.displayedJSON == nil)
        #expect(query.hasResult)
        #expect(query.namedResults.first?.name == "response")
        query.setState(.jsonLoaded(.object(["data": .null, "errors": .array([.object(["message": .string("Partial error")])])])))
        #expect(query.showsResultPane)
        #expect(query.displayedJSON == nil)
        query.setState(.failed("Failed"))
        #expect(query.showsResultPane)
        query.setState(.running)
        #expect(query.showsResultPane)
    }

    @Test func parsesMultipleWholeResponseAndExtractedBindings() throws {
        let source = NerdgraphCellSource(stored: """
            ```cell_config
            var: response
            var: entity = data.actor.entitySearch.results.entities[1]
            var: count = #data.actor.entitySearch.results.entities
            ```
            ```graphql
            { actor { user { name } } }
            ```
            """)
        #expect(source.bindingNames == ["response", "entity", "count"])
        #expect(try source.resultBindings().first?.expression == nil)
        #expect(source.format?.name == "response")
        #expect(try NerdgraphCellSource(stored: "```cell_config\nvar: whole response\n```\n```graphql\n{}\n```").resultBindings().first?.name == "whole response")
        let query = NrqlCell(text: source.storedText)
        let reader = NrqlCell(text: "```lua\nreturn results.entity\n```")
        #expect(NrqlDependencies.dependencies(of: reader, in: [query, reader]).map(\.id) == [query.id])
        #expect(throws: NrqlConnection.ConfigurationError.self) {
            try NerdgraphCellSource(stored: "```cell_config\nvar: entity\nvar: entity = data.actor\n```\n```graphql\n{}\n```").resultBindings()
        }
    }

    @Test func variablesInterpolateTypedValuesAndEscapeStrings() throws {
        let prior = [LuaRuntime.PriorResult(name: "input", value: .table([
            "id": .number(42), "text": .string("quote \" and newline\n"),
            "flags": .array([.bool(true), .bool(false)]),
            "filter": .table(["enabled": .bool(true)]),
        ]))]
        let value = try NrqlInterpolation.expandJSON("""
            {
              "id": {{ results.input.id }},
              "text": "prefix {{ results.input.text }}",
              "rawText": {{ results.input.text }},
              "flags": {{ results.input.flags }},
              "filter": {{ results.input.filter }}
            }
            """, results: prior)
        #expect(value["id"] == .number(42))
        #expect(value["text"] == .string("prefix quote \" and newline\n"))
        #expect(value["rawText"] == .string("quote \" and newline\n"))
        #expect(value["flags"] == .array([.bool(true), .bool(false)]))
        #expect(value["filter"] == .object(["enabled": .bool(true)]))
        #expect(throws: NrqlConnection.ConfigurationError.self) { try NrqlInterpolation.expandJSON("[]") }
        #expect(throws: NrqlInterpolation.InterpolationError.self) {
            try NrqlInterpolation.expandJSON(#"{"id": {{ results.missing.id }}}"#)
        }
        #expect(throws: (any Error).self) { try NrqlInterpolation.expandJSON(#"{"id": }"#) }
    }

    @Test func namedJSONResultsFeedScriptsAndOnlyVariablesCreateDependencies() async throws {
        let source = NrqlCell(text: "```cell_config\nvar: user\n```\n```graphql\n{ actor { user { name } } }\n```")
        let consumer = NrqlCell(text: """
            ```graphql
            query($id: Int!) { actor { account(id: $id) { name } } }
            ```
            ```variables
            {"id": {{ results.user.data.id }}}
            ```
            """)
        let value = JSONValue.object(["data": .object(["id": .number(123), "name": .string("Ada")])])
        source.query.setState(.jsonLoaded(value))
        let script = NrqlCell(text: "```lua\nreturn { rows = { { name = results.user.data.name } } }\n```")
        var document = NRQL_EditorDocument(text: "")
        document.cells = [source, consumer, script]
        #expect(NrqlDependencies.referencedNames(by: consumer) == ["user"])
        #expect(NrqlDependencies.plan(for: [consumer], in: document.cells, includeFinished: false).map(\.id) == [consumer.id])
        await script.query.getData(results: document.priorResults)
        #expect(script.query.resultContainer?.data.first?.stringFields["name"] == "Ada")
        document.clearResults()
        #expect(!source.query.hasResult)
    }

    @Test func accountChangesDoNotInvalidateGraphqlButKeyChangesDo() throws {
        let profile = NerdgraphProfile(name: "Production")
        let other = NerdgraphProfile(name: "Staging")
        let profiles = NerdgraphProfiles.Settings(profiles: [profile, other], defaultProfileID: profile.id)
        var document = NRQL_EditorDocument(text: "```graphql\n{ actor { user { name } } }\n```")
        let snapshot = try NrqlConnection().snapshot(profiles: profiles, requiresAccounts: false)
        document.cells[0].query.setState(.jsonLoaded(.object(["data": .object([:])])), connection: snapshot)
        try document.setDefaultAccountIds([123])
        #expect(document.staleCellIds(profiles: profiles).isEmpty)
        try document.setDefaultApiKey("Staging")
        #expect(document.staleCellIds(profiles: profiles) == [document.cells[1].id])
        #expect(try NrqlConnection.parse("api_key: Staging").apiKeyName == "Staging")
        document.cells[1].configurationText = "api-key: Production"
        #expect(document.staleCellIds(profiles: profiles).isEmpty)
    }

    @Test func JSONSearchFindsNestedKeysValuesAndArrayMembers() {
        let node = JSONNode(key: "$", value: .object([
            "entities": .array([.object(["name": .string("Checkout"), "id": .number(7)])]),
            "empty": .null
        ]))
        #expect(node.matches("checkout"))
        #expect(node.matches("NAME"))
        #expect(node.matches("null"))
        #expect(!node.matches("missing"))
        #expect(node.children?.map(\.key) == ["empty", "entities"])
    }

    @Test func JSONResultsPreserveLargeIntegersAndEscapedStrings() throws {
        let value = try JSONDecoder().decode(JSONValue.self, from: Data(#"{"id":9007199254740993,"text":"quote \" and newline\n"}"#.utf8))
        #expect(try value.encodedText().contains("9007199254740993"))
        #expect(JSONNode(key: "text", value: try #require(value["text"])).summary == #""quote \" and newline\n""#)
    }

    @Test func JSONCountsOnlyAppearForCollapsedContainers() {
        let object = JSONNode(key: "data", value: .object(["name": .string("Checkout")]))
        let array = JSONNode(key: "entities", value: .array([object.value]))
        #expect(object.displayValue(isExpanded: true) == nil)
        #expect(array.displayValue(isExpanded: true) == nil)
        #expect(object.displayValue(isExpanded: false) == "{ 1 fields }")
        #expect(array.displayValue(isExpanded: false) == "[ 1 items ]")
        #expect(JSONNode(key: "empty", value: .object([:])).displayValue(isExpanded: true) == "{}")
        #expect(JSONNode(key: "empty", value: .array([])).displayValue(isExpanded: true) == "[]")
        #expect(JSONNode(key: "name", value: .string("Checkout")).displayValue(isExpanded: true) == #""Checkout""#)
    }

    @Test func graphQLCommentsAreNotConfiguration() throws {
        let text = """

          # A note about this query
          # title: Account details: production

          # var: account_details
          # api-key: Production US
        query {
          # var: not_metadata
          actor { user { name } }
        }
        """
        let source = NerdgraphCellSource(editorText: text)
        #expect(source.operation == text)
        #expect(source.format == nil)
        #expect(source.bindingNames.isEmpty)
        #expect(try NrqlConnection.parse(source.metadata).apiKeyName == nil)
        let old = "/***\nvar: old_style\napi-key: Missing\n***/\n{ actor { user { name } } }"
        let oldSource = NerdgraphCellSource(editorText: old)
        #expect(oldSource.format == nil)
        #expect(oldSource.metadata.isEmpty)
        #expect(oldSource.operation == old)
    }
}

struct NrqlDocumentCellTests {
    @Test func documentConfigurationRoundTripsAndIsNotRunnable() throws {
        let text = "```config\napi-key: Production\naccounts: 12, 34\n```\n\n# Notes\n\n```nrql\nSELECT 1\n```\n"
        let document = NRQL_EditorDocument(text: text)
        #expect(document.cells.map(\.kind) == [.config, .markdown, .nrql])
        #expect(!document.cells[0].isRunnable)
        #expect(document.cells[0].query.nrql.isEmpty)
        #expect(document.text == text)
        #expect(try document.connection.get() == NrqlConnection(apiKeyName: "Production", accountIds: [12, 34]))
    }

    @Test func rejectsMisplacedRepeatedOrUnclosedConfiguration() {
        for text in [
            "# Title\n\n```config\napi-key: Work\n```",
            "```config\napi-key: Work\n```\n\n```config\naccounts: 12\n```",
            "```config\napi-key: Work\n"
        ] {
            #expect(throws: NrqlConnection.ConfigurationError.self) {
                try NRQL_EditorDocument(text: text).connection.get()
            }
        }
    }

    @Test func addsOneConfigurationAtTop() throws {
        var document = NRQL_EditorDocument(text: "```nrql\nSELECT 1\n```")
        document.addConfiguration()
        document.addConfiguration()
        #expect(document.cells.map(\.kind) == [.config, .nrql])
        #expect(document.focusedCellId == document.cells[0].id)
        #expect(document.cells[0].editorText.contains("author:"))
        #expect(document.cells[0].editorText.contains("description:"))
        #expect(try document.connection.get() == NrqlConnection())
    }

    @Test func toolbarDefaultsDoNotCreateAConfigCell() throws {
        var document = NRQL_EditorDocument(text: "```nrql\nSELECT 1\n```")
        try document.setDefaultApiKey(nil)
        try document.setDefaultAccountIds(nil)
        #expect(document.cells.map(\.kind) == [.nrql])
        #expect(try document.connection.get() == NrqlConnection())
    }

    @Test func toolbarSelectionsAddAndSynchronizeOnlyExplicitOverrides() throws {
        var document = NRQL_EditorDocument(text: "# Notes\n\n```nrql\nSELECT 1\n```")
        let queryID = document.cells[1].id
        let queryText = document.cells[1].text
        try document.setDefaultApiKey("Production US")
        #expect(document.cells.map(\.kind) == [.config, .markdown, .nrql])
        #expect(document.cells[0].editorText.contains("author:"))
        #expect(document.cells[0].editorText.contains("description:"))
        #expect(try document.connection.get() == NrqlConnection(apiKeyName: "Production US"))

        try document.setDefaultAccountIds([123, 456])
        let expected = NrqlConnection(apiKeyName: "Production US", accountIds: [123, 456])
        #expect(try document.connection.get() == expected)
        #expect(try NRQL_EditorDocument(text: document.text).connection.get() == expected)
        #expect(document.cells[2].id == queryID)
        #expect(document.cells[2].text == queryText)

        try document.setDefaultApiKey("Staging")
        #expect(try document.connection.get() == NrqlConnection(apiKeyName: "Staging", accountIds: [123, 456]))
        try document.setDefaultApiKey(nil)
        #expect(try document.connection.get() == NrqlConnection(accountIds: [123, 456]))
        try document.setDefaultAccountIds(nil)
        #expect(document.cells[0].editorText.contains("author:"))
        #expect(document.cells[0].editorText.contains("description:"))
        #expect(!document.cells[0].editorText.contains("api-key:"))
        #expect(!document.cells[0].editorText.contains("accounts:"))
        #expect(try document.connection.get() == NrqlConnection())
        #expect(try NRQL_EditorDocument(text: document.text).connection.get() == NrqlConnection())
    }

    @Test func selectingAccountsAloneAddsConfigAndDefaultPreservesTheKey() throws {
        var document = NRQL_EditorDocument(text: "```nrql\nSELECT 1\n```")
        try document.setDefaultAccountIds([789])
        #expect(document.cells[0].kind == .config)
        #expect(try document.connection.get() == NrqlConnection(accountIds: [789]))
        try document.setDefaultApiKey("Work")
        try document.setDefaultAccountIds(nil)
        #expect(try document.connection.get() == NrqlConnection(apiKeyName: "Work"))
    }

    @Test func showingConfigExpandsItAndKeepsItsContents() throws {
        var document = NRQL_EditorDocument(text: "```nrql\nSELECT 1\n```")
        try document.setDefaultApiKey("Work")
        let id = document.cells[0].id
        let text = document.cells[0].text
        document.cells[0].isCollapsed = true
        document.focusedCellId = document.cells[1].id
        document.addConfiguration()
        #expect(document.cells[0].id == id)
        #expect(document.cells[0].text == text)
        #expect(!document.cells[0].isCollapsed)
        #expect(document.focusedCellId == id)
    }

    @Test func toolbarChangesDoNotOverwriteMalformedConfig() {
        var document = NRQL_EditorDocument(text: "```config\napi-key:\n```")
        let originalText = document.text
        #expect(throws: NrqlConnection.ConfigurationError.self) { try document.setDefaultApiKey("Work") }
        #expect(document.text == originalText)
    }

    @Test func toolbarChangesPreserveDocumentMetadataIncludingPendingEdits() throws {
        var document = NRQL_EditorDocument(text: "```config\nauthor: Before\naccounts: 12\n```")
        document.cells[0].query.text = """
            ```config
            author: Ada
            description: Error rates: per application
            owner-team: Observability
            custom-notes:
            // Keep this note.
            accounts: 12
            ```
            """
        try document.setDefaultApiKey("Production")
        try document.setDefaultAccountIds([34, 56])
        #expect(try document.connection.get() == NrqlConnection(apiKeyName: "Production", accountIds: [34, 56]))
        try document.setDefaultApiKey(nil)
        try document.setDefaultAccountIds(nil)

        #expect(document.cells[0].editorText == """
            author: Ada
            description: Error rates: per application
            owner-team: Observability
            custom-notes:
            // Keep this note.
            """)
        #expect(try document.connection.get() == NrqlConnection())
        let reopened = NRQL_EditorDocument(text: document.text)
        #expect(reopened.cells[0].editorText == document.cells[0].editorText)
        #expect(try reopened.connection.get() == NrqlConnection())
    }

    @Test func collapsesAndExpandsConfigAlongsideCode() throws {
        var document = NRQL_EditorDocument(text: NrqlDocumentParser.join([
            NrqlCellKind.config.template, "# Notes", NrqlCellKind.nrql.template, NrqlCellKind.lua.template
        ]))
        let originalText = document.text
        let originalConnection = try document.connection.get()
        document.setAllCollapsed(true)
        #expect(document.cells.map(\.isCollapsed) == [true, false, true, true])
        #expect(document.text == originalText)
        #expect(try document.connection.get() == originalConnection)
        document.setAllCollapsed(false)
        #expect(document.cells.allSatisfy { !$0.isCollapsed })
    }

    @Test func executionReadsPendingConfigEditsBeforeDocumentDebounce() throws {
        let document = NRQL_EditorDocument(text: "```config\napi-key: Old\naccounts: 1\n```")
        document.cells[0].query.text = "```config\napi-key: New\naccounts: 2\n```"
        #expect(try document.connection.get() == NrqlConnection(apiKeyName: "New", accountIds: [2]))
    }

    @Test func documentTextRoundTripsThroughCells() {
        let text = "# Title\n\n```nrql\n// A\nSELECT 1\n```\n\n```nrql\nSELECT 2\n```\n"
        let document = NRQL_EditorDocument(text: text)

        #expect(document.cells.map(\.kind) == [.markdown, .nrql, .nrql])
        #expect(document.text == text)
    }

    @Test func editingACellChangesDocumentTextAndQuery() {
        var document = NRQL_EditorDocument(text: "```nrql\nSELECT 1\n```")
        document.cells[0].editorText = "SELECT 2"

        #expect(document.text == "```nrql\nSELECT 2\n```\n")
        #expect(document.cells[0].query.nrql == "SELECT 2")
    }

    @Test func markdownCellsAreInertAndDontReadResults() {
        let cell = NrqlCell(text: "Uses results.foo.rows and {{ x }}")

        #expect(cell.kind == .markdown)
        #expect(!cell.isRunnable)
        #expect(NrqlDependencies.referencedNames(by: cell).isEmpty)
        #expect(cell.query.nrql.isEmpty)
    }

    @Test func addAndRemoveCells() {
        var document = NRQL_EditorDocument(text: "```nrql\nSELECT 1\n```")
        let id = document.addCell(after: document.cells.last?.id)

        #expect(document.cells.count == 2)
        #expect(document.focusedCellId == id)
        #expect(document.cells[1].text == NrqlCellKind.nrql.template)

        document.removeCell(id)
        #expect(document.cells.count == 1)
        #expect(document.focusedCellId == nil)
    }
}

struct NrqlConnectionTests {
    @Test(arguments: [
        "/*\napi-key: Work\n*/",
        "/***\napi-key: Work",
        "/***\napi-key: Work\n***/\naccounts: 123",
        "/***\napi-key: Work\n***/\n/***\naccounts: 123\n***/"
    ])
    func documentSettingsRejectCommentWrappers(_ body: String) {
        let document = NRQL_EditorDocument(text: "```config\n\(body)\n```")
        #expect(throws: NrqlConnection.ConfigurationError.self) { try document.connection.get() }
    }

    @Test func parsesRoutingAlongsideChartSettingsAndInheritsEachField() throws {
        let body = "title: Errors: per day\napi-key: Staging\naccounts: 7, 8, 7\nchart: line"
        let connection = try NrqlConnection.parse(body)
        #expect(connection == NrqlConnection(apiKeyName: "Staging", accountIds: [7, 8]))
        let defaults = NrqlConnection(apiKeyName: "Production", accountIds: [1, 2])
        #expect(NrqlConnection(accountIds: [9]).inheriting(defaults) == NrqlConnection(apiKeyName: "Production", accountIds: [9]))
        #expect(NrqlConnection(apiKeyName: "Other").inheriting(defaults) == NrqlConnection(apiKeyName: "Other", accountIds: [1, 2]))
        #expect(NrqlConnection().inheriting(defaults) == defaults)
        let query = NrqlQuery(from: "```cell_config\n\(body)\n```\n```nrql\nSELECT 1\n```")
        #expect(query.nrql == "SELECT 1")
        #expect(query.format?.type == .line)
    }

    @Test(arguments: [
        "accounts:", "accounts: 0", "accounts: -1", "accounts: 1,wat", "accounts: 1,,2",
        "accounts: 2147483648", "api-key:", "api-key: NRAK-secret", "api-key: A\napi-key: B"
    ])
    func rejectsInvalidRoutingInsteadOfFallingBack(_ body: String) {
        #expect(throws: (any Error).self) { try NrqlConnection.parse(body) }
    }

    @Test func documentConfigAllowsMetadataAndIgnoresLineCommentSettings() throws {
        let config = try NrqlConnection.parseDocumentConfig(
            "author: Ada\ndescription: Report: per day\nowner-team: Observability\ncustom:\n// api-key: Ignored\napi-key: Work\n// accounts: 999\naccounts: 123"
        )
        #expect(config == NrqlConnection(apiKeyName: "Work", accountIds: [123]))
        #expect(try NrqlConnection.parseDocumentConfig("account: 123") == NrqlConnection())
    }

    @Test(arguments: ["api-key:", "accounts:", "accounts: invalid", "accounts: 1\naccounts: 2", "missing colon"])
    func metadataDoesNotDisableConfigurationValidation(_ body: String) {
        #expect(throws: (any Error).self) {
            try NrqlConnection.parseDocumentConfig("author: Ada\ndescription:\n\(body)")
        }
    }
}

struct NrqlQueryTests {
    @Test(arguments: [
        "```cell_config\nvar: source\n```\n```nrql\nSELECT 1\n```",
        "```cell_config\nvar: source\n```\n```lua\nreturn { rows = {} }\n```",
        "```cell_config\nvar: source\n```\n```graphql\n{ actor { user { name } } }\n```"
    ])
    func bindsResultsWithVarWithoutANameAlias(_ text: String) {
        #expect(NrqlQuery(from: text).name == "source")
        let old = text.replacingOccurrences(of: "var: source", with: "name: source")
        #expect(NrqlQuery(from: old).name == nil)
    }

    @Test func formatTitleOverridesCommentTitle() {
        let query = NrqlQuery(from: "```cell_config\ntitle: Errors: last day\n```\n```nrql\n// Comment title\nSELECT 1\n```")

        #expect(query.title == "Errors: last day")
        #expect(NrqlQuery(from: "// Comment title\nSELECT 1").title == "Comment title")
    }

    @Test func formatBlockIsNotPartOfTheQueryOrTitle() {
        let query = NrqlQuery(from: "```cell_config\nchart: line\nattributes: points\n```\n```nrql\n// Title\nSELECT 1\n```")

        #expect(query.nrql == "SELECT 1")
        #expect(query.title == "NRQL Query")
        #expect(query.format?.type == .line)
    }

    @Test(arguments: [
        "```cell_config\napi-key: Work\naccounts: 123\n```\n```nrql\n// Legacy title\nSELECT 1\n```",
        "```cell_config\nvar: query_result\n```\n```nrql\n// Legacy title\nSELECT 1\n```",
        "```cell_config\n\n```\n```nrql\n// Legacy title\nSELECT 1\n```"
    ])
    func metadataBlockDisablesLineCommentTitleFallback(_ text: String) {
        #expect(NrqlQuery(from: text).title == "NRQL Query")
    }

    @Test func lineCommentsSupplyOnlyTheLegacyQueryTitle() throws {
        let text = "// Legacy title\n// api-key: Ignored\n// accounts: 999\n// chart: line\nSELECT 1"
        let query = NrqlQuery(from: text)
        #expect(query.title == "Legacy title")
        #expect(query.name == nil)
        #expect(query.format == nil)
        #expect(query.nrql == "SELECT 1")
        #expect(try NrqlConnection.parse(NrqlConnection.metadataBody(in: text)) == NrqlConnection())
    }

    @Test func stripsCommentsAndFindsTitle() {
        let query = NrqlQuery(from: "// My title\nSELECT 1\nFROM A")

        #expect(query.nrql == "SELECT 1\nFROM A")
        #expect(query.title == "My title")
        #expect(query.resultContainer == nil)
        #expect(!query.isRunning)
    }

    @Test func updatingTextUpdatesNrql() {
        let query = NrqlQuery(from: "SELECT 1")
        query.text = "// new\nSELECT 2"

        #expect(query.nrql == "SELECT 2")
    }
}

@MainActor
struct NrqlExportTests {
    @Test func exportsConfiguredChartHeightAndFitsTallChartsOnPdfPages() throws {
        let document = NRQL_EditorDocument(text: """
            ```cell_config
            title: Large billboard
            height: 80
            ```
            ```nrql
            SELECT count(*) FROM Transaction
            ```
            """)
        let results = try JSONDecoder().decode(NrdbResultContainer.self, from: Data(
            #"{"nrql":"","results":[{"count":5}],"metadata":{}}"#.utf8
        ))
        document.cells[0].query.setState(.loaded(results))
        let html = NrqlExport.html(for: document)
        let start = try #require(html.range(of: "data:image/png;base64,")?.upperBound)
        let end = try #require(html[start...].firstIndex(of: "\""))
        let png = try #require(Data(base64Encoded: String(html[start..<end])))
        let image = try #require(NSBitmapImageRep(data: png))
        #expect(image.pixelsHigh == 2400)

        let data = try #require(NrqlExport.data(for: .pdf, document: document))
        let pdf = try #require(PDFDocument(data: data))
        #expect(pdf.pageCount == 1)
        let page = try #require(pdf.page(at: 0))
        #expect(page.string?.contains("Large billboard") == true)
        let contentBounds = page.bounds(for: .mediaBox).insetBy(dx: 39, dy: 39)
        for index in 0..<page.numberOfCharacters {
            let bounds = page.characterBounds(at: index)
            if !bounds.isEmpty { #expect(contentBounds.contains(bounds)) }
        }
    }

    private func pdfText(for document: NRQL_EditorDocument) throws -> String {
        let data = try #require(NrqlExport.data(for: .pdf, document: document))
        return try #require(PDFDocument(data: data)?.string)
    }

    @Test func exportsNerdgraphVariablesAsSeparateLabeledCodeBlock() throws {
        var document = NRQL_EditorDocument(text: """
            ```graphql
            query($id: Int!) { actor { account(id: $id) { name } } }
            ```
            ```variables
            {"id": 42}
            ```
            """)
        let html = NrqlExport.html(for: document)
        #expect(html.contains("</pre>\n<h3>Variables:</h3>\n<pre>{\"id\": 42}</pre>"))
        #expect(!html.contains("```"))
        let pdf = try pdfText(for: document)
        #expect(pdf.contains("Variables:"))
        #expect(pdf.contains("\"id\": 42"))
        #expect(!pdf.contains("```"))

        document.cells[0].configurationText = "query: hide"
        #expect(!NrqlExport.html(for: document).contains("Variables:"))
        #expect(try !pdfText(for: document).contains("Variables:"))
        let withoutVariables = NRQL_EditorDocument(text: "```graphql\n{ actor { user { name } } }\n```")
        #expect(!NrqlExport.html(for: withoutVariables).contains("Variables:"))
    }

    @Test func exportsResolvedQueriesAndVariablesFromAvailableDependencies() throws {
        let document = NRQL_EditorDocument(text: """
            ```config
            accounts: 42
            ```

            ```cell_config
            var: app
            query: hide
            chart: none
            ```
            ```lua
            return {}
            ```

            ```nrql
            FROM Transaction SELECT count(*) WHERE appName = '{{ results.app.rows[1].facet }}'
            ```

            ```graphql
            query($id: Int!, $name: String!) { actor { account(id: $id) { name } } }
            ```
            ```variables
            {"id": {{ config.accounts[1] }}, "name": "{{ results.app.rows[1].facet }}"}
            ```
            """)
        let result = try JSONDecoder().decode(NrdbResultContainer.self, from: Data(
            #"{"nrql":"","results":[{"facet":"Shop & More","count":1}],"metadata":{}}"#.utf8
        ))
        document.cells[1].query.setState(.loaded(result))
        let original = document.text
        let html = NrqlExport.html(for: document)
        #expect(html.contains("appName = 'Shop &amp; More'"))
        #expect(html.contains("\"id\" : 42"))
        #expect(html.contains("\"name\" : \"Shop &amp; More\""))
        #expect(!html.contains("{{"))
        let pdf = try pdfText(for: document)
        #expect(pdf.contains("appName = 'Shop & More'"))
        #expect(pdf.contains("\"id\" : 42"))
        #expect(pdf.contains("\"name\" : \"Shop & More\""))
        #expect(!pdf.contains("{{"))
        #expect(document.text == original)
        #expect(document.cells[2].query.executedNrql == nil)
    }

    @Test func exportsOriginalCodeWhenSubstitutionDependenciesAreMissing() throws {
        let document = NRQL_EditorDocument(text: """
            ```nrql
            SELECT {{ 1 + 1 }} FROM {{ results.missing.rows[1].name }}
            ```

            ```graphql
            query($id: Int!) { actor { account(id: $id) { name } } }
            ```
            ```variables
            {"id": {{ results.missing.rows[1].id }}}
            ```
            """)
        let html = NrqlExport.html(for: document)
        let pdf = try pdfText(for: document)
        for text in [html, pdf] {
            #expect(text.contains("SELECT {{ 1 + 1 }}"))
            #expect(text.contains("{{ results.missing.rows[1].id }}"))
            #expect(text.contains("Variables:"))
            #expect(!text.contains("```"))
        }
    }

    @Test(arguments: [
        (NrqlCellKind.nrql, "SELECT 'HIDDEN_CODE_MARKER'"),
        (.lua, "return { rows = { { value = 'HIDDEN_CODE_MARKER' } } }"),
        (.nerdgraph, "{ actor { user { name } } }\n# HIDDEN_CODE_MARKER")
    ])
    func queryVisibilityControlsHtmlAndPdfRegardlessOfLiveCollapse(kind: NrqlCellKind, code: String) throws {
        var document = NRQL_EditorDocument(text: """
            ```cell_config
            title: Hidden calculation
            query: hide
            chart: json
            ```
            \(kind.wrap(code))

            ```cell_config
            title: Visible query
            query: show
            ```
            ```nrql
            SELECT 'VISIBLE_CODE_MARKER'
            ```
            """)
        document.cells[0].isCollapsed = false
        document.cells[1].isCollapsed = true
        document.cells[0].query.setState(.jsonLoaded(.object(["value": .string("RESULT_MARKER")])))

        let html = NrqlExport.html(for: document)
        #expect(!html.contains("HIDDEN_CODE_MARKER"))
        #expect(html.contains("VISIBLE_CODE_MARKER"))
        #expect(html.contains("<h2>Hidden calculation</h2>"))
        #expect(html.contains("RESULT_MARKER"))

        let data = try #require(NrqlExport.data(for: .pdf, document: document))
        let text = try #require(PDFDocument(data: data)?.string)
        #expect(!text.contains("HIDDEN_CODE_MARKER"))
        #expect(text.contains("VISIBLE_CODE_MARKER"))
        #expect(text.contains("Hidden calculation"))
        #expect(text.contains("RESULT_MARKER"))

        document.cells[0].configurationText = "title: Hidden calculation\nquery: show\nchart: json"
        #expect(NrqlExport.html(for: document).contains("HIDDEN_CODE_MARKER"))
        let shownData = try #require(NrqlExport.data(for: .pdf, document: document))
        #expect(try #require(PDFDocument(data: shownData)?.string).contains("HIDDEN_CODE_MARKER"))
    }

    @Test func exportsHtmlAndPdf() throws {
        let document = NRQL_EditorDocument(text: "# Intro & more\n\n```nrql\n// A & B\nSELECT 1 FROM Log WHERE x < 2\n```")

        let html = NrqlExport.html(for: document)
        #expect(html.contains("<h2>A &amp; B</h2>"))
        #expect(html.contains("x &lt; 2"))
        #expect(html.contains("<h1>Intro &amp; more</h1>"))
        #expect(!html.contains("```"))

        let pdf = try #require(NrqlExport.data(for: .pdf, document: document))
        #expect(pdf.starts(with: Array("%PDF".utf8)))
    }

    @Test func pdfFlowsCellsAcrossPages() throws {
        func pageCount(_ text: String) throws -> Int {
            let data = try #require(NrqlExport.data(for: .pdf, document: NRQL_EditorDocument(text: text)))
            let pdf = try #require(CGDataProvider(data: data as CFData).flatMap { CGPDFDocument($0) })
            return pdf.numberOfPages
        }
        let short = "Intro\n\n```nrql\nSELECT 1 FROM Log\n```\n\n```nrql\nSELECT 2 FROM Log\n```"
        #expect(try pageCount(short) == 1)
        let long = (0..<60).map { "Paragraph \($0)" }.joined(separator: "\n\n")
        #expect(try pageCount(long) > 1)
    }

    @Test func exportsChartsOfLoadedResults() throws {
        let document = NRQL_EditorDocument(text: "```nrql\nSELECT count(*) FROM Log TIMESERIES\n```")
        let results = try #require(ChartSamples.sampleData(size: .small))
        document.cells[0].query.setState(.loaded(results))

        let pdf = try #require(NrqlExport.data(for: .pdf, document: document))
        #expect(pdf.starts(with: Array("%PDF".utf8)))
        #expect(NrqlExport.html(for: document).contains("data:image/png;base64,"))
    }

    @Test func exportsTablesAsData() throws {
        let document = NRQL_EditorDocument(text: "```cell_config\nchart: table\n```\n```nrql\nSELECT * FROM Log\n```")
        let results = try #require(ChartSamples.sampleData(timeseries: false, size: .large))
        document.cells[0].query.setState(.loaded(results))

        let table = try #require(NrqlExport.tableData(for: document.cells[0]))
        #expect(table.rows.count == results.data.count)
        #expect(NrqlExport.html(for: document).contains("<table>"))
        if results.data.count > 100 { #expect(NrqlExport.html(for: document).contains("Showing 100 of")) }
        #expect(!NrqlExport.html(for: document).contains("data:image/png"))
        #expect(try #require(NrqlExport.data(for: .pdf, document: document)).starts(with: Array("%PDF".utf8)))
    }
}

struct NrqlInterpolationTests {
    private let results = [
        LuaRuntime.PriorResult(
            name: "top_app",
            value: .table(["rows": .array([.table(["facet": .string("Shop"), "count": .number(42)])])])
        )
    ]

    @Test func expandsExpressionsFromResults() throws {
        let nrql = "FROM Metric WHERE appName = '{{ results.top_app.rows[1].facet }}' LIMIT {{ results.top_app.rows[1].count }}"

        #expect(try NrqlInterpolation.expand(nrql, results: results) == "FROM Metric WHERE appName = 'Shop' LIMIT 42")
        #expect(try NrqlInterpolation.expand("SELECT 1") == "SELECT 1")
    }

    @Test func configWorksInQueryTextAndTypedJSONVariables() throws {
        let config = NrqlConnection(apiKeyName: "Production", accountIds: [42, 17])
        #expect(try NrqlInterpolation.expand("SELECT {{ config.accounts[1] }}", config: config) == "SELECT 42")
        let variables = try NrqlInterpolation.expandJSON(
            #"{"id": {{ config.accounts[1] }}, "accounts": {{ config.accounts }}, "key": "{{ config.api_key }}"}"#,
            config: config
        )
        #expect(variables["id"] == .number(42))
        #expect(variables["accounts"] == .array([.number(42), .number(17)]))
        #expect(variables["key"] == .string("Production"))
    }

    @Test func reportsMissingResults() {
        #expect(throws: NrqlInterpolation.InterpolationError.self) {
            try NrqlInterpolation.expand("WHERE a = '{{ results.nope.rows[1].facet }}'", results: results)
        }
    }

    @Test func formatVariableAndHiddenChart() {
        let query = NrqlQuery(from: "```cell_config\nvar: top_app\nchart: none\n```\n```nrql\nSELECT 1\n```")

        #expect(query.name == "top_app")
        #expect(query.format?.hidesChart == true)
        #expect(query.format?.type == nil)
    }
}

@MainActor
struct NrqlClearResultsTests {
    @Test func clearsResultsAndErrorsWithoutChangingTheDocument() throws {
        var document = NRQL_EditorDocument(text: """
            ```config
            accounts: 12
            ```

            # Notes

            ```cell_config
            var: source
            ```
            ```nrql
            SELECT count(*) FROM Log
            ```

            ```lua
            emit(results.source.rows)
            ```

            ```nrql
            SELECT 1
            ```
            """)
        let data = try #require(ChartSamples.sampleData(size: .small))
        let source = document.cells[2].query
        source.setState(.loaded(data))
        document.cells[3].query.setState(.failed("Script failed"))
        document.cells[4].query.setState(.running)
        document.cells[2].isCollapsed = true
        document.focusedCellId = document.cells[3].id
        let text = document.text
        let ids = document.cells.map(\.id)
        let focus = document.focusedCellId
        #expect(!document.priorResults.isEmpty)
        #expect(source.loadedAt != nil)

        document.clearResults()

        for cell in document.cells {
            guard case .idle = cell.query.state else {
                Issue.record("Cleared cells must return to idle")
                continue
            }
            #expect(cell.query.resultContainer == nil)
            #expect(cell.query.errorMessage == nil)
            #expect(cell.query.loadedAt == nil)
            #expect(cell.query.executedNrql == nil)
        }
        #expect(document.priorResults.isEmpty)
        #expect(document.completionScope(excluding: document.cells[3].id).results.isEmpty)
        #expect(document.staleCellIds(profiles: NerdgraphProfiles.Settings()).isEmpty)
        #expect(document.text == text)
        #expect(document.cells.map(\.id) == ids)
        #expect(document.focusedCellId == focus)
        #expect(document.cells[2].isCollapsed)
        #expect(try document.connection.get() == NrqlConnection(accountIds: [12]))
    }

    @Test func clearCancelsQueuedRunsAcrossDocumentCopiesAndAllowsRerunning() async {
        let document = NRQL_EditorDocument(text: "```lua\nreturn { rows = { { count = 1 } } }\n```\n\n```lua\nreturn { rows = { { count = 2 } } }\n```")
        let run = document.runAllQueries()
        let copy = document
        copy.clearResults()
        await run.value

        #expect(run.isCancelled)
        for cell in document.cells {
            if case .idle = cell.query.state {} else {
                Issue.record("A queued run restored a cleared result")
            }
        }

        await document.runAllQueries().value
        #expect(document.cells.allSatisfy { $0.query.resultContainer != nil })
    }

    @Test func cancelledQueryCannotStartAfterClearing() async {
        let query = NrqlQuery(from: "```lua\nreturn { rows = { { count = 1 } } }\n```")
        let run = Task { await query.getData() }
        run.cancel()
        query.clearResults()
        await run.value
        if case .idle = query.state {} else {
            Issue.record("A cancelled run changed the cleared state")
        }
    }
}

struct NrqlScriptCellTests {
    private let script = "```cell_config\nvar: x\n```\n```lua\n-- Compare\n\nemit({ rows = { { facet = 'A', count = results.a.rows[1].count } } })\n```"

    @Test func documentVariablesAreExecutedAndTrackedForStaleness() async throws {
        let suite = "NR Status document globals test \(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set(try JSONEncoder().encode(NerdgraphProfiles.Settings()), forKey: "nerdgraphProfiles")
        let document = NRQL_EditorDocument(text: """
            ```config
            var appName = "Foo"
            ```

            ```lua
            return { rows = { { name = config.appName } } }
            ```
            """)
        let query = document.cells[1].query
        await query.getData(defaults: try document.connection.get(), profiles: NerdgraphProfiles(defaults: defaults))
        #expect(query.errorMessage == nil)
        #expect(query.resultContainer?.data.first?.stringFields["name"] == "Foo")
        document.cells[0].query.text = "```config\nvar appName = \"Bar\"\n```"
        #expect(document.staleCellIds(profiles: .init()) == [document.cells[1].id])
    }

    @Test(arguments: [true, false])
    func scriptsReadDocumentOverridesOrProfileDefaults(explicitConfig: Bool) async throws {
        let suite = "NR Status Lua config test \(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let profile = NerdgraphProfile(name: "Production", preferredAccountIds: [42, 17])
        defaults.set(
            try JSONEncoder().encode(NerdgraphProfiles.Settings(profiles: [profile], defaultProfileID: profile.id)),
            forKey: "nerdgraphProfiles"
        )
        let profiles = NerdgraphProfiles(defaults: defaults)
        let prefix = explicitConfig ? "```config\naccounts: 23, 11\n```\n\n" : ""
        let document = NRQL_EditorDocument(text: prefix + """
            ```lua
            return { rows = { { account = config.accounts[1], key = config.api_key } } }
            ```
            """)
        let query = try #require(document.cells.last?.query)
        await query.getData(defaults: try document.connection.get(), profiles: profiles)
        #expect(query.errorMessage == nil)
        #expect(query.resultContainer?.data.first?.numberFields["account"] == (explicitConfig ? 23 : 42))
        #expect(query.resultContainer?.data.first?.stringFields["key"] == "Production")
        #expect(query.loadedDocumentConfig?.accountIds == (explicitConfig ? [23, 11] : [42, 17]))
    }

    @Test func configAllowsNoProfilesButReportsAnUnknownConfiguredKey() async throws {
        let suite = "NR Status empty config test \(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set(try JSONEncoder().encode(NerdgraphProfiles.Settings()), forKey: "nerdgraphProfiles")
        let profiles = NerdgraphProfiles(defaults: defaults)
        let query = NrqlQuery(from: "```lua\nreturn { rows = { { count = #config.accounts } } }\n```")
        await query.getData(profiles: profiles)
        #expect(query.errorMessage == nil)
        #expect(query.resultContainer?.data.first?.numberFields["count"] == 0)
        await query.getData(defaults: NrqlConnection(apiKeyName: "Unknown"), profiles: profiles)
        #expect(query.errorMessage == NerdgraphProfiles.ProfileError.missingProfile.localizedDescription)
    }

    @Test func fencedScriptSurvivesBlankLinesAndRoundTrips() {
        let text = "```nrql\nFROM A SELECT 1\n```\n\n\(script)\n\n```nrql\nFROM B SELECT 2\n```\n"
        let blocks = NrqlDocumentParser.blocks(text)

        #expect(blocks.count == 3)
        #expect(blocks[1] == script)
        #expect(NrqlDocumentParser.join(blocks) == text)
    }

    @Test func scriptCellIsRecognized() {
        let query = NrqlQuery(from: script)

        #expect(query.isScript)
        #expect(query.nrql.isEmpty)
        #expect(query.title == "Lua Script")
        #expect(query.name == "x")
        #expect(NrqlCell(text: script).isRunnable)
    }

    @Test func luaFormatIsALeadingComment() {
        let query = NrqlQuery(from: "```cell_config\ntitle: T\nchart: bar\n```\n```lua\n--[[ later ]]\nreturn 1\n```")

        #expect(query.format?.type == .bar)
        #expect(query.title == "T")
        #expect(query.script?.contains("--[[ later ]]") == true)
        #expect(NrqlQuery(from: "```lua\nreturn 1 --[[ chart: bar ]]\n```").format == nil)
    }

    @Test func scriptCellProducesAResult() async {
        let query = NrqlQuery(from: script)
        let prior = LuaRuntime.PriorResult(
            name: "a", value: .table(["rows": .array([.table(["count": .number(3)])])])
        )
        await query.getData(results: [prior])

        #expect(query.resultContainer?.data.count == 1)
        #expect(query.errorMessage == nil)
    }
}

struct NrqlDependencyTests {
    private let cells = [
        NrqlCell(text: "```cell_config\nvar: c\n```\n```nrql\nFROM A WHERE x = '{{ results.b.rows[1].facet }}'\n```"),
        NrqlCell(text: "```cell_config\nvar: b\n```\n```nrql\nFROM B WHERE x = '{{ results.a.rows[1].facet }}'\n```"),
        NrqlCell(text: "```cell_config\nvar: a\n```\n```nrql\nFROM C\n```"),
        NrqlCell(text: "```lua\nemit(results['c'].rows)\n```"),
        NrqlCell(text: "```nrql\nFROM D -- results.a is not in a placeholder\n```"),
    ]

    private func names(_ plan: [NrqlCell]) -> [String] { plan.map { $0.query.name ?? $0.query.title } }

    @Test func plansDependenciesFirst() {
        #expect(names(NrqlDependencies.plan(for: [cells[3]], in: cells, includeFinished: false)) == ["a", "b", "c", "Lua Script"])
        #expect(NrqlDependencies.plan(for: [cells[4]], in: cells, includeFinished: false).count == 1)
    }

    @Test func runAllOrdersByDependency() {
        let order = names(NrqlDependencies.plan(for: cells, in: cells, includeFinished: true))

        #expect(order == ["a", "b", "c", "Lua Script", "NRQL Query"])
    }

    @Test func cyclesDoNotLoop() {
        let loop = [
            NrqlCell(text: "```cell_config\nvar: x\n```\n```nrql\nFROM A WHERE a = '{{ results.y.n }}'\n```"),
            NrqlCell(text: "```cell_config\nvar: y\n```\n```nrql\nFROM B WHERE a = '{{ results.x.n }}'\n```"),
        ]

        #expect(NrqlDependencies.plan(for: [loop[0]], in: loop, includeFinished: false).count == 2)
    }
}

struct NrqlCellActionTests {
    @MainActor @Test func duplicatesCodeBelowWithIndependentStateAndUniqueBindings() throws {
        var document = NRQL_EditorDocument(text: """
            ```cell_config
            title: Requests
            var: requests
            chart: billboard
            attributes: gauge, max(250)
            future: preserved
            ```
            ```nrql
            SELECT count(*) FROM Transaction
            ```

            # Notes
            """)
        let original = document.cells[0]
        original.query.setState(.loaded(try #require(ChartSamples.sampleData(size: .small))))
        document.perform(.duplicate, on: original.id)
        let copy = document.cells[1]
        #expect(document.cells.map(\.kind) == [.nrql, .nrql, .markdown])
        #expect(copy.id != original.id && copy.query !== original.query)
        #expect(copy.editorText == original.editorText)
        #expect(copy.query.title == "Requests (copy)")
        #expect(copy.query.name == "requests_copy")
        #expect(copy.query.format?.parameter("max") == "250")
        #expect(copy.configurationText.contains("future: preserved"))
        #expect(!copy.query.hasResult && original.query.hasResult)
        #expect(document.focusedCellId == copy.id && copy.focusOnAppear)
        document.perform(.duplicate, on: original.id)
        #expect(document.cells[1].query.name == "requests_copy2")
        #expect(NRQL_EditorDocument(text: document.text).text == document.text)
        #expect(document.cells[0].text == original.text)
    }

    @Test func duplicatesNerdgraphBindingsWithoutChangingExpressionsOrVariables() throws {
        var document = NRQL_EditorDocument(text: """
            ```cell_config
            var: response
            var: entity = data.actor.entities[1]
            var: count = #data.actor.entities
            ```
            ```graphql
            query($id: Int!) { actor { user { name } } }
            ```
            ```variables
            {"id": 42}
            ```
            """)
        let original = document.cells[0]
        document.perform(.duplicate, on: original.id)
        let copy = document.cells[1]
        let bindings = try NerdgraphCellSource(stored: copy.text).resultBindings()
        #expect(bindings.map(\.name) == ["response_copy", "entity_copy", "count_copy"])
        #expect(bindings.map(\.expression) == [nil, "data.actor.entities[1]", "#data.actor.entities"])
        #expect(copy.editorText == original.editorText)
        #expect(copy.query.variables == original.query.variables)
    }

    @Test func duplicatesMarkdownAndPendingCodeButNotDocumentDefaults() {
        var document = NRQL_EditorDocument(text: "```config\nauthor: Ada\n```\n\n# Notes\n\n```lua\n-- Title\nreturn 1\n```")
        #expect(!document.canPerform(.duplicate, on: document.cells[0].id))
        document.perform(.duplicate, on: document.cells[0].id)
        #expect(document.cells.count == 3)
        document.perform(.duplicate, on: document.cells[1].id)
        #expect(document.cells[1].text == document.cells[2].text)
        let sourceID = document.cells[3].id
        document.cells[3].query.text = "```lua\n-- Updated title\nreturn 2\n```"
        document.perform(.duplicate, on: sourceID)
        #expect(document.cells[4].editorText == "-- Updated title\nreturn 2")
        #expect(document.cells[4].query.title == "Updated title (copy)")
        #expect(document.cells[3].editorText == "-- Title\nreturn 1")
    }

    @Test func scriptCellsHideTheirFence() {
        let stored = "```cell_config\nvar: x\n```\n```lua\nlocal a = 1\n\nreturn a\n```"
        var cell = NrqlCell(text: stored)
        #expect(cell.kind == .lua)
        #expect(cell.editorText == "local a = 1\n\nreturn a")
        cell.editorText = "return 2"
        #expect(cell.text == "```cell_config\nvar: x\n```\n```lua\nreturn 2\n```")
        #expect(cell.query.script?.contains("return 2") == true)
        #expect(cell.query.name == "x")
    }

    @Test func emptyScriptRoundTrips() {
        var cell = NrqlCell(text: NrqlCellKind.lua.template)
        #expect(cell.editorText == "")
        cell.editorText = ""
        #expect(cell.text == NrqlCellKind.lua.template)
    }

    @Test func convertsBetweenKinds() {
        var doc = NRQL_EditorDocument(text: "```nrql\nFROM A\n```")
        let id = doc.cells[0].id
        doc.perform(.convert(.lua), on: id)
        #expect(doc.cells[0].kind == .lua && doc.cells[0].text == "```lua\nFROM A\n```")
        doc.perform(.convert(.markdown), on: id)
        #expect(doc.cells[0].kind == .markdown && doc.cells[0].text == "FROM A")
        #expect(!doc.canPerform(.convert(.markdown), on: id))
        doc.perform(.convert(.nrql), on: id)
        #expect(doc.cells[0].kind == .nrql && doc.cells[0].query.nrql == "FROM A")
    }

    @Test func flagsCellsReadingResultsFromBelow() {
        let doc = NRQL_EditorDocument(text: """
            ```nrql
            SELECT 1 FROM A WHERE x = '{{ results.later.v }}'
            ```

            ```cell_config
            var: later
            ```
            ```nrql
            SELECT 2 FROM B
            ```
            """)
        #expect(doc.readingBelowCellIds == [doc.cells[0].id])
    }

    private func titles(_ doc: NRQL_EditorDocument) -> [String] { doc.cells.map(\.editorText) }

    @Test func addsAboveAndBelow() {
        var doc = NRQL_EditorDocument(text: "```nrql\nFROM A\n```\n\n```nrql\nFROM B\n```")
        let b = doc.cells[1].id
        doc.perform(.add(.lua, above: true), on: b)
        doc.perform(.add(.markdown, above: false), on: b)
        #expect(doc.cells.map(\.kind) == [.nrql, .lua, .nrql, .markdown])
        #expect(titles(doc) == ["FROM A", "", "FROM B", ""])
        #expect(doc.focusedCellId == doc.cells[3].id)
    }

    @Test func addsAtTop() {
        var doc = NRQL_EditorDocument(text: "```nrql\nFROM A\n```")
        doc.perform(.add(.nrql, above: true), on: doc.cells[0].id)
        #expect(titles(doc) == ["FROM ", "FROM A"])
    }

    @Test func movesWithinBounds() {
        var doc = NRQL_EditorDocument(text: "```nrql\nFROM A\n```\n\n```nrql\nFROM B\n```\n\n```nrql\nFROM C\n```")
        let a = doc.cells[0].id, c = doc.cells[2].id
        #expect(!doc.canPerform(.moveUp, on: a))
        #expect(!doc.canPerform(.moveDown, on: c))
        doc.perform(.moveDown, on: a)
        #expect(titles(doc) == ["FROM B", "FROM A", "FROM C"])
        doc.perform(.moveUp, on: c)
        #expect(titles(doc) == ["FROM B", "FROM C", "FROM A"])
    }
}

struct MarkdownParserTests {
    @MainActor @Test func markdownInterpolatesConfigAndResultsWithoutChangingSource() throws {
        let document = NRQL_EditorDocument(text: """
            ```config
            var appName = "Foo"
            ```

            # {{ config.appName }}

            Entity: **{{ results.entity.data.name }}**

            ```cell_config
            var: entity
            ```
            ```graphql
            { actor { user { name } } }
            ```
            """)
        let markdown = document.cells[1]
        let source = document.cells[2].query
        let original = document.text
        source.setState(.jsonLoaded(.object(["data": .object(["name": .string("Ada")])])))
        let rendered = try document.markdownText(for: markdown, profiles: .init())
        #expect(rendered.contains("# Foo"))
        #expect(rendered.contains("**Ada**"))
        #expect(NrqlExport.html(for: document).contains("<strong>Ada</strong>"))
        #expect(document.text == original)
        source.setState(.jsonLoaded(.object(["data": .object(["name": .string("Grace")])])))
        #expect(try document.markdownText(for: markdown, profiles: .init()).contains("**Grace**"))
        source.clearResults()
        #expect(throws: NrqlInterpolation.InterpolationError.self) {
            try document.markdownText(for: markdown, profiles: .init())
        }
    }

    @Test func parsesBlocks() {
        let blocks = MarkdownParser.blocks("# Title\nline one\nline two\n\n- a\n- b\n\n1. x\n\n> q\n\n```\ncode\n\nmore\n```\n---")

        #expect(blocks == [
            .heading(level: 1, text: "Title"),
            .paragraph("line one line two"),
            .bullets(["a", "b"]),
            .numbered(["x"]),
            .quote("q"),
            .code("code\n\nmore"),
            .rule,
        ])
    }

    @Test func rendersInlineHtml() {
        #expect(MarkdownParser.html("Use **bold**, *it* and `a<b`") == "<p>Use <strong>bold</strong>, <em>it</em> and <code>a&lt;b</code></p>")
    }
}

struct NrqlStaleTests {
    @Test func cellIsStaleWhenADependencyRunsAgain() async {
        let a = NrqlCell(text: "```cell_config\nvar: a\n```\n```lua\nreturn { { n = 1 } }\n```")
        let b = NrqlCell(text: "```cell_config\nvar: b\n```\n```lua\nreturn { { n = results.a.rows[1].n } }\n```")
        let c = NrqlCell(text: "```lua\nreturn { { n = results.b.rows[1].n } }\n```")
        let cells = [a, b, c]

        #expect(NrqlDependencies.staleCells(in: cells).isEmpty)

        for cell in cells {
            let prior = [LuaRuntime.PriorResult(name: "a", value: .table(["rows": .array([.table(["n": .number(1)])])])),
                         LuaRuntime.PriorResult(name: "b", value: .table(["rows": .array([.table(["n": .number(1)])])]))]
            await cell.query.getData(results: prior)
        }
        #expect(NrqlDependencies.staleCells(in: cells).isEmpty)

        await a.query.getData()
        #expect(NrqlDependencies.staleCells(in: cells) == [b.id, c.id])
    }
}

@MainActor
struct NrqlConnectionStaleTests {
    private let production = NerdgraphProfile(name: "Production", preferredAccountIds: [10, 20])
    private let staging = NerdgraphProfile(name: "Staging", preferredAccountIds: [30])

    private var profiles: NerdgraphProfiles.Settings {
        NerdgraphProfiles.Settings(profiles: [production, staging], defaultProfileID: production.id)
    }

    @Test func configReadersTrackAccountOrderAndInvalidateTheirReaders() throws {
        let document = NRQL_EditorDocument(text: """
            ```cell_config
            var: selected
            ```
            ```lua
            return { rows = { { id = config.accounts[1] } } }
            ```

            ```lua
            return results.selected
            ```

            ```lua
            return { rows = {} }
            ```

            ```graphql
            query($id: Int!) { actor { account(id: $id) { id } } }
            ```
            ```variables
            {"id": {{ config.accounts[1] }}}
            ```
            """)
        let config = try document.connection.get().effectiveConfiguration(profiles: profiles)
        let data = try #require(ChartSamples.sampleData(size: .small))
        for cell in document.cells {
            cell.query.setState(.loaded(data), documentConfig: cell.query.readsDocumentConfig ? config : nil)
        }
        #expect(document.staleCellIds(profiles: profiles).isEmpty)
        var reordered = profiles
        reordered.profiles[0].preferredAccountIds = [20, 10]
        #expect(document.staleCellIds(profiles: reordered) == [
            document.cells[0].id, document.cells[1].id, document.cells[3].id
        ])
        document.clearResults()
        #expect(document.staleCellIds(profiles: reordered).isEmpty)
        #expect(document.cells[0].query.loadedDocumentConfig == nil)
    }

    private func cacheResults(in document: NRQL_EditorDocument, profiles: NerdgraphProfiles.Settings) throws {
        let data = try #require(ChartSamples.sampleData(size: .small))
        for cell in NrqlDependencies.plan(for: document.cells, in: document.cells, includeFinished: true) {
            let snapshot: NrqlConnection.Snapshot?
            if cell.kind == .nrql {
                snapshot = try NrqlConnection.parse(cell.configurationText)
                    .inheriting(document.connection.get())
                    .snapshot(profiles: profiles)
            } else {
                snapshot = nil
            }
            cell.query.setState(.loaded(data), connection: snapshot)
        }
    }

    @Test(arguments: [true, false])
    func documentChangesOnlyInvalidateInheritedFieldsAndTheirReaders(changingKey: Bool) throws {
        var document = NRQL_EditorDocument(text: """
            ```config
            api-key: Production
            accounts: 10
            ```

            ```cell_config
            var: source
            ```
            ```nrql
            SELECT 1
            ```

            ```cell_config
            api-key: Staging
            ```
            ```nrql
            SELECT 2
            ```

            ```cell_config
            accounts: 30
            ```
            ```nrql
            SELECT 3
            ```

            ```cell_config
            api-key: Staging
            accounts: 30
            ```
            ```nrql
            SELECT 4
            ```

            ```cell_config
            var: derived
            ```
            ```lua
            return results.source
            ```

            ```lua
            return results.derived
            ```

            ```lua
            return { rows = { { count = 1 } } }
            ```
            """)
        try cacheResults(in: document, profiles: profiles)
        #expect(document.staleCellIds(profiles: profiles).isEmpty)

        if changingKey {
            try document.setDefaultApiKey("Staging")
        } else {
            try document.setDefaultAccountIds([20])
        }
        let affected = [1, changingKey ? 3 : 2, 5, 6].map { document.cells[$0].id }
        let stale = document.staleCellIds(profiles: profiles)
        #expect(stale == Set(affected))
        #expect(document.pendingDependencies(for: document.cells[6].id, stale: stale).map(\.id)
                == [document.cells[1].id, document.cells[5].id])
        #expect(NrqlDependencies.plan(for: [document.cells[6]], in: document.cells, includeFinished: false, stale: stale).map(\.id)
                == [document.cells[1].id, document.cells[5].id, document.cells[6].id])

        try cacheResults(in: document, profiles: profiles)
        #expect(document.staleCellIds(profiles: profiles).isEmpty)
    }

    @Test(arguments: [true, false])
    func pendingEditorChangesInvalidateCachedResults(editingDocumentConfig: Bool) throws {
        let document = NRQL_EditorDocument(text: """
            ```config
            api-key: Production
            ```

            ```cell_config
            var: source
            ```
            ```nrql
            SELECT 1
            ```

            ```lua
            return results.source
            ```
            """)
        try cacheResults(in: document, profiles: profiles)
        let text = document.text
        if editingDocumentConfig {
            document.cells[0].query.text = "```config\napi-key: Staging\n```"
        } else {
            document.cells[1].query.text = "```cell_config\nvar: source\naccounts: 30\n```\n```nrql\nSELECT 1\n```"
        }
        #expect(document.text == text)
        #expect(document.staleCellIds(profiles: profiles) == [document.cells[1].id, document.cells[2].id])
    }

    @Test(arguments: [true, false])
    func inheritedAppDefaultsAndPreferredAccountsAreTracked(changingKey: Bool) throws {
        let document = NRQL_EditorDocument(text: """
            ```cell_config
            var: source
            ```
            ```nrql
            SELECT 1
            ```

            ```lua
            return results.source
            ```

            ```cell_config
            api-key: Staging
            accounts: 30
            ```
            ```nrql
            SELECT 2
            ```
            """)
        try cacheResults(in: document, profiles: profiles)
        var updated = profiles
        if changingKey {
            updated.defaultProfileID = staging.id
        } else {
            updated.profiles[0].preferredAccountIds = [20]
        }
        #expect(document.staleCellIds(profiles: updated) == [document.cells[0].id, document.cells[1].id])
    }

    @Test func equivalentSelectionsAndClearedResultsAreNotStale() throws {
        var document = NRQL_EditorDocument(text: "```nrql\nSELECT 1\n```")
        try cacheResults(in: document, profiles: profiles)
        try document.setDefaultApiKey("production")
        try document.setDefaultAccountIds([20, 10])
        #expect(document.staleCellIds(profiles: profiles).isEmpty)
        document.cells[0].editorText = document.cells[0].editorText
            .replacingOccurrences(of: "author:", with: "author: Ada")
            .replacingOccurrences(of: "description:", with: "description: Updated report")
        #expect(document.staleCellIds(profiles: profiles).isEmpty)

        try document.setDefaultAccountIds([30])
        #expect(document.staleCellIds(profiles: profiles) == [document.cells[1].id])
        document.clearResults()
        #expect(document.staleCellIds(profiles: profiles).isEmpty)
        #expect(document.cells[1].query.loadedConnection == nil)
    }
}
