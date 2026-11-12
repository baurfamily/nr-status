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
        #expect(!document.cells[1].isRunnable)

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
