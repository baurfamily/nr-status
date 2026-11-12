//
//  NrqlCompletionTests.swift
//  NR StatusTests
//

import Testing
import Foundation
@testable import NR_Status

struct NrqlCompletionTests {
    struct StubMetadata: NrqlMetadataProviding {
        func eventTypes() async -> [String] { ["Transaction", "TransactionError", "PageView"] }
        func attributes(event: String) async -> [Attribute] {
            event == "Transaction"
                ? [Attribute(event: event, type: "string", key: "name"), Attribute(event: event, type: "numeric", key: "duration"),
                   Attribute(event: event, type: "string", key: "weird key")]
                : []
        }
    }

    /// `|` marks the cursor.
    private func names(_ marked: String) async -> [String] {
        let location = (marked as NSString).range(of: "|").location
        let text = marked.replacingOccurrences(of: "|", with: "")
        return await NrqlCompletion.items(text: text, location: location, metadata: StubMetadata()).items.map(\.name)
    }

    @Test func suggestsClauseKeywords() async {
        #expect(await names("SELECT count(*) FROM Transaction FA|") == ["FACET"])
        // SELECT may come before or after FROM
        #expect(await names("FROM Transaction SELECT count(*) FA|") == ["FACET"])
        #expect(await names("FROM Transaction SELECT count(*) WH|") == ["WHERE"])
        #expect(await names("SELECT count(*) FROM Transaction WH|") == ["WHERE"])
        #expect(await names("SELECT count(*) FROM Transaction SINCE 1 day ago TIM|") == ["TIMESERIES"])
        #expect(await names("SELECT count(*) FROM Transaction FACET name LIM|") == ["LIMIT"])
        #expect(await names("SELECT count(*) FROM Transaction LIMIT 10 SIN|") == ["SINCE"])
        #expect(await names("SELECT count(*) FROM Transaction WHERE name = 'a' AN|") == ["AND"])
        // FROM comes first in a query, so nothing else is offered before it
        #expect(await names("SELECT count(*) FA|").isEmpty)
        #expect(await names("SELECT count(*) FR|") == ["FROM"])
        #expect(await names("FROM Transaction SE|") == ["SELECT"])
        #expect(await names("FROM Transaction FA|").isEmpty)
        // once-only clauses aren't offered twice
        #expect(await names("SELECT count(*) FROM Transaction FACET name FAC|").isEmpty)
        #expect(await names("SELECT count(*) FROM Transaction WHERE a = 1 AND b = 2 WH|") == ["WHERE"])
    }

    @Test func suggestsEventTypesAfterFrom() async {
        #expect(await names("SELECT count(*) FROM Tra|") == ["Transaction", "TransactionError"])
        #expect(await names("SELECT count(*) FROM |").count == 3)
    }

    @Test func suggestsAttributesOfTheFromEvent() async {
        // the event comes after the cursor
        let select = await names("SELECT av| FROM Transaction")
        #expect(select.contains("average"))
        #expect(!select.contains("duration"))
        #expect(await names("SELECT count(*) FROM Transaction FACET na|") == ["name"])
        // functions and keywords are offered alongside attributes
        let filtered = await names("SELECT count(*) FROM Transaction WHERE d|")
        #expect(filtered.contains("duration") && filtered.contains("derivative"))
    }

    @Test func quotesAwkwardAttributeNames() async {
        let text = "SELECT count(*) FROM Transaction FACET w"
        let items = await NrqlCompletion.items(text: text, location: text.utf16.count, metadata: StubMetadata()).items
        #expect(items.first { $0.name == "weird key" }?.insertText == "`weird key`")
    }

    @Test func replacesOnlyThePartialWord() async {
        let text = "SELECT count(*) FROM Tra"
        let result = await NrqlCompletion.items(text: text, location: text.utf16.count, metadata: StubMetadata())
        #expect(result.range == NSRange(location: 21, length: 3))
    }

    @Test func staysQuietInCommentsAndStrings() async {
        #expect(await names("// FROM Tra|").isEmpty)
        #expect(await names("SELECT 1 FROM Transaction WHERE name = 'FROM Tra|").isEmpty)
        #expect(await names("/* SELECT cou| */").isEmpty)
        // a FROM inside a comment doesn't decide the context
        #expect(await names("// FROM\nSELECT cou|").contains("count"))
    }

    @Test func completesFormatBlock() async {
        #expect(await names("/***\n  ti|\n***/") == ["title"])
        #expect(await names("/***\nchart: p|\n***/") == ["pie", "plot"])
        #expect(await names("/***\nchart: pie\nattributes: |\n***/") == ["donut", "separated"])
        #expect(await names("/***\nchart: plot\nattributes: x-|\n***/") == ["x-log"])
        #expect(await names("/***\ntitle: Fo|\n***/").isEmpty)
    }

    @Test func offersAfterSeparators() {
        func offers(_ marked: String) -> Bool {
            let loc = (marked as NSString).range(of: "|").location
            return NrqlCompletion.offersAfterSeparator(text: marked.replacingOccurrences(of: "|", with: ""), location: loc)
        }
        #expect(offers("/***\nchart: line\nattributes: stacked, |\n***/"))
        #expect(offers("/***\nchart: line\nattributes: stacked |\n***/"))
        #expect(offers("SELECT count(*), |"))
        #expect(offers("SELECT count(*) FROM |"))
        #expect(!offers("SELECT count(*) |"))
        #expect(!offers("// note, |"))
    }
}
