//
//  LuaCompletionTests.swift
//  NR StatusTests
//

import Testing
import Foundation
import LuaSwift
@testable import NR_Status

struct LuaCompletionTests {
    private let scope = LuaCompletion.Scope(
        names: ["top_app", "pending"],
        results: [
            LuaRuntime.PriorResult(
                name: "top_app",
                value: .table([
                    "nrql": .string("SELECT 1"),
                    "columns": .array([.string("facet"), .string("count")]),
                    "rows": .array([.table(["facet": .string("Shop"), "count": .number(42)])]),
                ])
            )
        ]
    )

    // `|` marks the cursor
    private func names(_ marked: String, expression: Bool = false) -> [String] {
        let location = (marked as NSString).range(of: "|").location
        let text = marked.replacingOccurrences(of: "|", with: "")
        return LuaCompletion.items(text: text, location: location, scope: scope, isExpression: expression).items.map(\.name)
    }

    @Test func offersGlobalsKeywordsAndLocals() {
        let found = names("local total = 1\nlocal function helper() end\nreturn to|")
        #expect(found.contains("total") && found.contains("tostring") && found.contains("tonumber"))
        #expect(names("fu|").contains("function"))
        #expect(names("local helper = 1\nhel|") == ["helper"])
        // the word being typed isn't offered back
        #expect(!names("local tot|").contains("tot"))
    }

    @Test func offersResultNamesAfterResults() {
        #expect(names("results.|") == ["top_app", "pending"])
        #expect(names("results.to|") == ["top_app"])
    }

    @Test func offersDocumentConfigInScriptsAndExpressions() {
        #expect(names("con|") == ["config"])
        #expect(names("con|", expression: true) == ["config"])
        #expect(names("config.|") == ["accounts", "api_key"])
        #expect(names("config.acc|", expression: true) == ["accounts"])
        let scope = LuaCompletion.Scope(variables: ["appName"])
        #expect(LuaCompletion.items(text: "app", location: 3, scope: scope).items.isEmpty)
        #expect(LuaCompletion.items(text: "config.app", location: 10, scope: scope).items.map(\.name) == ["appName"])
    }

    @Test func offersFieldsOfLoadedResults() {
        #expect(names("results.top_app.|") == ["columns", "nrql", "rows"])
        #expect(names("results.top_app.rows[1].|") == ["count", "facet"])
        #expect(names("local x = results.top_app.rows[1].fa|") == ["facet"])
        // a named cell that hasn't run still has the usual fields
        #expect(names("results.pending.|") == ["columns", "nrql", "rows"])
        #expect(names("results.nobody.|").isEmpty)
    }

    @Test func offersStandardLibraryMembers() {
        #expect(names("string.fo|") == ["format"])
        #expect(names("math.|").contains("floor"))
        #expect(names("local t = {}\nt.|").isEmpty)
    }

    @Test func staysQuietInCommentsStringsAndConcatenation() {
        #expect(names("-- res|").isEmpty)
        #expect(names("print(\"res|").isEmpty)
        #expect(names("local s = a..|").isEmpty)
    }

    @Test func expressionsOfferOnlyValues() {
        let found = names("lo|", expression: true)
        #expect(!found.contains("local"))
        #expect(names("re|", expression: true) == ["results"])
    }

    @Test func findsTheInterpolationAroundTheCursor() {
        let text = "FROM A WHERE x = '{{ results.top_app.rows[1].fa"
        #expect(LuaCompletion.interpolationStart(in: text, at: (text as NSString).length) == 20)
        let closed = "WHERE x = '{{ 1 }}' AND y = "
        #expect(LuaCompletion.interpolationStart(in: closed, at: (closed as NSString).length) == nil)
        #expect(LuaCompletion.interpolationStart(in: "SELECT 1", at: 8) == nil)
    }
}
