//
//  NrqlDocumentTests.swift
//  NR StatusTests
//

import Testing
import Foundation
@testable import NR_Status

struct NrqlDocumentParserTests {
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

    @Test func blocksKeepCommentOnlyBlocksAndRoundTrip() {
        let text = "// just a note\n\nSELECT 1\nFROM A\n\n\n// Two\nSELECT 2\n"
        let blocks = NrqlDocumentParser.blocks(text)

        #expect(blocks == ["// just a note", "SELECT 1\nFROM A", "// Two\nSELECT 2"])
        #expect(NrqlDocumentParser.blocks(NrqlDocumentParser.join(blocks)) == blocks)
    }

    @Test func joinDropsBlankLinesInsideABlock() {
        #expect(NrqlDocumentParser.join(["SELECT 1\n\nFROM A", "SELECT 2"]) == "SELECT 1\nFROM A\n\nSELECT 2\n")
    }
}

struct NrqlDocumentCellTests {
    @Test func documentTextRoundTripsThroughCells() {
        let document = NRQL_EditorDocument(text: "// A\nSELECT 1\n\nSELECT 2\n")

        #expect(document.cells.count == 2)
        #expect(document.text == "// A\nSELECT 1\n\nSELECT 2\n")
    }

    @Test func editingACellChangesDocumentTextAndQuery() {
        var document = NRQL_EditorDocument(text: "SELECT 1")
        document.cells[0].text = "SELECT 2"

        #expect(document.text == "SELECT 2\n")
        #expect(document.cells[0].query.nrql == "SELECT 2")
    }

    @Test func addAndRemoveCells() {
        var document = NRQL_EditorDocument(text: "SELECT 1")
        let id = document.addCell(after: document.cells.last?.id)

        #expect(document.cells.count == 2)
        #expect(document.focusedCellId == id)
        #expect(document.cells[1].text == "FROM ")

        document.removeCell(id)
        #expect(document.cells.count == 1)
        #expect(document.focusedCellId == nil)
    }
}

struct NrqlQueryTests {
    @Test func formatTitleOverridesCommentTitle() {
        let query = NrqlQuery(from: "/***\ntitle: Errors: last day\n***/\n// Comment title\nSELECT 1")

        #expect(query.title == "Errors: last day")
        #expect(NrqlQuery(from: "// Comment title\nSELECT 1").title == "Comment title")
    }

    @Test func formatBlockIsNotPartOfTheQueryOrTitle() {
        let query = NrqlQuery(from: "/***\ntype: line\nattributes: points\n***/\n// Title\nSELECT 1")

        #expect(query.nrql == "SELECT 1")
        #expect(query.title == "Title")
        #expect(query.format?.type == .line)
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
    @Test func exportsTextHtmlAndPdf() throws {
        let document = NRQL_EditorDocument(text: "// A & B\nSELECT 1 FROM Log WHERE x < 2")

        #expect(String(data: try #require(NrqlExport.data(for: .nrql, document: document)), encoding: .utf8) == document.text)

        let html = NrqlExport.html(for: document)
        #expect(html.contains("<h2>A &amp; B</h2>"))
        #expect(html.contains("x &lt; 2"))

        let pdf = try #require(NrqlExport.data(for: .pdf, document: document))
        #expect(pdf.starts(with: Array("%PDF".utf8)))
    }

    @Test func exportsChartsOfLoadedResults() throws {
        let document = NRQL_EditorDocument(text: "SELECT count(*) FROM Log TIMESERIES")
        let results = try #require(ChartSamples.sampleData(size: .small))
        document.cells[0].query.setState(.loaded(results))

        let pdf = try #require(NrqlExport.data(for: .pdf, document: document))
        #expect(pdf.starts(with: Array("%PDF".utf8)))
        #expect(NrqlExport.html(for: document).contains("data:image/png;base64,"))
    }

    @Test func exportsTablesAsData() throws {
        let document = NRQL_EditorDocument(text: "/***\ntype: table\n***/\nSELECT * FROM Log")
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
        let query = NrqlQuery(from: "/***\nname: top_app\ntype: none\n***/\nSELECT 1")

        #expect(query.name == "top_app")
        #expect(query.format?.hidesChart == true)
        #expect(query.format?.type == nil)
    }
}

struct NrqlScriptCellTests {
    private let script = "/***\nname: x\n***/\n```lua\n-- Compare\n\nemit({ rows = { { facet = 'A', count = results.a.rows[1].count } } })\n```"

    @Test func fencedScriptSurvivesBlankLinesAndRoundTrips() {
        let text = "FROM A SELECT 1\n\n\(script)\n\nFROM B SELECT 2\n"
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
