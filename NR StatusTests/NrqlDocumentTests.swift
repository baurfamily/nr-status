//
//  NrqlDocumentTests.swift
//  NR StatusTests
//

import Testing
import Foundation
import CoreGraphics
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

struct NrqlDocumentCellTests {
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

struct NrqlQueryTests {
    @Test func formatTitleOverridesCommentTitle() {
        let query = NrqlQuery(from: "/***\ntitle: Errors: last day\n***/\n// Comment title\nSELECT 1")

        #expect(query.title == "Errors: last day")
        #expect(NrqlQuery(from: "// Comment title\nSELECT 1").title == "Comment title")
    }

    @Test func formatBlockIsNotPartOfTheQueryOrTitle() {
        let query = NrqlQuery(from: "/***\nchart: line\nattributes: points\n***/\n// Title\nSELECT 1")

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
