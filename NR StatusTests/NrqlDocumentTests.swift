//
//  NrqlDocumentTests.swift
//  NR StatusTests
//

import Testing
import Foundation
import CoreGraphics
@testable import NR_Status

struct NrqlDocumentParserTests {
    @Test func graphqlAndVariablesFormOneCellAndRoundTrip() {
        let text = """
        # Notes

        ```graphql
        # name: user
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
        #expect(NrqlCellKind.nerdgraph.wrap(cell.editorText) == cell.text)
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
        let source = NrqlCell(text: "```graphql\n# name: user\n{ actor { user { name } } }\n```")
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
        document.cells[1].editorText = "# api-key: Production\n" + document.cells[1].editorText
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

    @Test func GraphQLMetadataOnlyUsesLeadingNativeComments() throws {
        let text = """

          # A note about this query
          # title: Account details: production

          # name: account_details
          # api-key: Production US
        query {
          # name: not_metadata
          actor { user { name } }
        }
        """
        let source = NerdgraphCellSource(editorText: text)
        #expect(source.operation == text)
        #expect(source.format?.title == "Account details: production")
        #expect(source.format?.name == "account_details")
        #expect(try NrqlConnection.parse(source.metadata).apiKeyName == "Production US")
        let old = "/***\nname: old_style\napi-key: Missing\n***/\n{ actor { user { name } } }"
        let oldSource = NerdgraphCellSource(editorText: old)
        #expect(oldSource.format == nil)
        #expect(oldSource.metadata.isEmpty)
        #expect(oldSource.operation == old)
    }
}

struct NrqlDocumentCellTests {
    @Test func documentConfigurationRoundTripsAndIsNotRunnable() throws {
        let text = "```config\n/***\napi-key: Production\naccounts: 12, 34\n***/\n```\n\n# Notes\n\n```nrql\nSELECT 1\n```\n"
        let document = NRQL_EditorDocument(text: text)
        #expect(document.cells.map(\.kind) == [.config, .markdown, .nrql])
        #expect(!document.cells[0].isRunnable)
        #expect(document.cells[0].query.nrql.isEmpty)
        #expect(document.text == text)
        #expect(try document.connection.get() == NrqlConnection(apiKeyName: "Production", accountIds: [12, 34]))
    }

    @Test func rejectsMisplacedRepeatedOrUnclosedConfiguration() {
        for text in [
            "# Title\n\n```config\n/***\napi-key: Work\n***/\n```",
            "```config\n/***\napi-key: Work\n***/\n```\n\n```config\n/***\naccounts: 12\n***/\n```",
            "```config\n/***\napi-key: Work\n***/"
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
        var document = NRQL_EditorDocument(text: "```config\n/***\napi-key:\n***/\n```")
        let originalText = document.text
        #expect(throws: NrqlConnection.ConfigurationError.self) { try document.setDefaultApiKey("Work") }
        #expect(document.text == originalText)
    }

    @Test func toolbarChangesPreserveDocumentMetadataIncludingPendingEdits() throws {
        var document = NRQL_EditorDocument(text: "```config\n/***\n  author: Before\n  accounts: 12\n***/\n```")
        document.cells[0].query.text = """
            ```config
            /***
              author: Ada
              description: Error rates: per application
              owner-team: Observability
              custom-notes:
              // Keep this note.
              accounts: 12
            ***/
            ```
            """
        try document.setDefaultApiKey("Production")
        try document.setDefaultAccountIds([34, 56])
        #expect(try document.connection.get() == NrqlConnection(apiKeyName: "Production", accountIds: [34, 56]))
        try document.setDefaultApiKey(nil)
        try document.setDefaultAccountIds(nil)

        #expect(document.cells[0].editorText == """
            /***
              author: Ada
              description: Error rates: per application
              owner-team: Observability
              custom-notes:
              // Keep this note.
            ***/
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
        let document = NRQL_EditorDocument(text: "```config\n/***\napi-key: Old\naccounts: 1\n***/\n```")
        document.cells[0].query.text = "```config\n/***\napi-key: New\naccounts: 2\n***/\n```"
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
        "api-key: Work\naccounts: 123",
        "// api-key: Work\n// accounts: 123",
        "/*\napi-key: Work\n*/",
        "/***\napi-key: Work",
        "/***\napi-key: Work\n***/\naccounts: 123",
        "/***\napi-key: Work\n***/\n/***\naccounts: 123\n***/"
    ])
    func documentSettingsRequireASingleBlockComment(_ body: String) {
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
        let query = NrqlQuery(from: "/***\n\(body)\n***/\nSELECT 1")
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
            "/***\nauthor: Ada\ndescription: Report: per day\nowner-team: Observability\ncustom:\n// api-key: Ignored\napi-key: Work\n// accounts: 999\naccounts: 123\n***/"
        )
        #expect(config == NrqlConnection(apiKeyName: "Work", accountIds: [123]))
        #expect(try NrqlConnection.parseDocumentConfig("/***\naccount: 123\n***/") == NrqlConnection())
    }

    @Test(arguments: ["api-key:", "accounts:", "accounts: invalid", "accounts: 1\naccounts: 2", "missing colon"])
    func metadataDoesNotDisableConfigurationValidation(_ body: String) {
        #expect(throws: (any Error).self) {
            try NrqlConnection.parseDocumentConfig("/***\nauthor: Ada\ndescription:\n\(body)\n***/")
        }
    }
}

struct NrqlQueryTests {
    @Test func formatTitleOverridesCommentTitle() {
        let query = NrqlQuery(from: "/***\ntitle: Errors: last day\n***/\n// Comment title\nSELECT 1")

        #expect(query.title == "Errors: last day")
        #expect(NrqlQuery(from: "// Comment title\nSELECT 1").title == "Comment title")
    }

    @Test func formatBlockIsNotPartOfTheQueryOrTitle() {
        let query = NrqlQuery(from: "/***\nchart: line\nattributes: points\n***/\n// Title\nSELECT 1")

        #expect(query.nrql == "SELECT 1")
        #expect(query.title == "NRQL Query")
        #expect(query.format?.type == .line)
    }

    @Test(arguments: [
        "/***\napi-key: Work\naccounts: 123\n***/\n// Legacy title\nSELECT 1",
        "// Legacy title\n/***\nname: query_result\n***/\nSELECT 1",
        "/***\n***/\n// Legacy title\nSELECT 1"
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
        let document = NRQL_EditorDocument(text: "```nrql\n/***\nchart: table\n***/\nSELECT * FROM Log\n```")
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

    @Test func reportsMissingResults() {
        #expect(throws: NrqlInterpolation.InterpolationError.self) {
            try NrqlInterpolation.expand("WHERE a = '{{ results.nope.rows[1].facet }}'", results: results)
        }
    }

    @Test func formatNameAndHiddenChart() {
        let query = NrqlQuery(from: "/***\nname: top_app\nchart: none\n***/\nSELECT 1")

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
            /***
            accounts: 12
            ***/
            ```

            # Notes

            ```nrql
            /*** name: source ***/
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
    private let script = "```lua\n--[[\nname: x\n]]\n-- Compare\n\nemit({ rows = { { facet = 'A', count = results.a.rows[1].count } } })\n```"

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
        #expect(query.title == "Compare")
        #expect(query.name == "x")
        #expect(NrqlCell(text: script).isRunnable)
    }

    @Test func luaFormatIsALeadingComment() {
        let query = NrqlQuery(from: "```lua\n--[[\ntitle: T\nchart: bar\n]]\n--[[ later ]]\nreturn 1\n```")

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
        NrqlCell(text: "```nrql\n/***\nname: c\n***/\nFROM A WHERE x = '{{ results.b.rows[1].facet }}'\n```"),
        NrqlCell(text: "```nrql\n/***\nname: b\n***/\nFROM B WHERE x = '{{ results.a.rows[1].facet }}'\n```"),
        NrqlCell(text: "```nrql\n/***\nname: a\n***/\nFROM C\n```"),
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
            NrqlCell(text: "```nrql\n/***\nname: x\n***/\nFROM A WHERE a = '{{ results.y.n }}'\n```"),
            NrqlCell(text: "```nrql\n/***\nname: y\n***/\nFROM B WHERE a = '{{ results.x.n }}'\n```"),
        ]

        #expect(NrqlDependencies.plan(for: [loop[0]], in: loop, includeFinished: false).count == 2)
    }
}

struct NrqlCellActionTests {
    @Test func scriptCellsHideTheirFence() {
        let stored = "```lua\n--[[ name: x ]]\nlocal a = 1\n\nreturn a\n```"
        var cell = NrqlCell(text: stored)
        #expect(cell.kind == .lua)
        #expect(cell.editorText == "--[[ name: x ]]\nlocal a = 1\n\nreturn a")
        cell.editorText = "--[[ name: x ]]\nreturn 2"
        #expect(cell.text == "```lua\n--[[ name: x ]]\nreturn 2\n```")
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

            ```nrql
            /*** name: later ***/
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
        let a = NrqlCell(text: "```lua\n--[[\nname: a\n]]\nreturn { { n = 1 } }\n```")
        let b = NrqlCell(text: "```lua\n--[[\nname: b\n]]\nreturn { { n = results.a.rows[1].n } }\n```")
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

    private func cacheResults(in document: NRQL_EditorDocument, profiles: NerdgraphProfiles.Settings) throws {
        let data = try #require(ChartSamples.sampleData(size: .small))
        for cell in NrqlDependencies.plan(for: document.cells, in: document.cells, includeFinished: true) {
            let snapshot: NrqlConnection.Snapshot?
            if cell.kind == .nrql {
                snapshot = try NrqlConnection.parse(NrqlConnection.metadataBody(in: cell.editorText))
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
            /***
            api-key: Production
            accounts: 10
            ***/
            ```

            ```nrql
            /*** name: source ***/
            SELECT 1
            ```

            ```nrql
            /*** api-key: Staging ***/
            SELECT 2
            ```

            ```nrql
            /*** accounts: 30 ***/
            SELECT 3
            ```

            ```nrql
            /***
            api-key: Staging
            accounts: 30
            ***/
            SELECT 4
            ```

            ```lua
            --[[ name: derived ]]
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
            /*** api-key: Production ***/
            ```

            ```nrql
            /*** name: source ***/
            SELECT 1
            ```

            ```lua
            return results.source
            ```
            """)
        try cacheResults(in: document, profiles: profiles)
        let text = document.text
        if editingDocumentConfig {
            document.cells[0].query.text = "```config\n/*** api-key: Staging ***/\n```"
        } else {
            document.cells[1].query.text = "```nrql\n/***\nname: source\naccounts: 30\n***/\nSELECT 1\n```"
        }
        #expect(document.text == text)
        #expect(document.staleCellIds(profiles: profiles) == [document.cells[1].id, document.cells[2].id])
    }

    @Test(arguments: [true, false])
    func inheritedAppDefaultsAndPreferredAccountsAreTracked(changingKey: Bool) throws {
        let document = NRQL_EditorDocument(text: """
            ```nrql
            /*** name: source ***/
            SELECT 1
            ```

            ```lua
            return results.source
            ```

            ```nrql
            /***
            api-key: Staging
            accounts: 30
            ***/
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
