//
//  LuaRuntimeTests.swift
//  NR StatusTests
//

import Testing
import Foundation
import LuaSwift
@testable import NR_Status

struct LuaRuntimeTests {
    @Test func returnsValue() throws {
        let outcome = try LuaRuntime.run("return 1 + 1")
        #expect(outcome.value.numberValue == 2)
    }

    @Test func emitOverridesReturn() throws {
        let outcome = try LuaRuntime.run("emit({ a = 1 }); return 5")
        #expect(outcome.value.tableValue?["a"]?.intValue == 1)
    }

    @Test func capturesPrint() throws {
        let outcome = try LuaRuntime.run("print('a', 1); return nil")
        #expect(outcome.output == ["a\t1"])
    }

    @Test func configProvidesOrderedAccountsAndNonSecretKeyName() throws {
        let config = NrqlConnection(apiKeyName: "Production", accountIds: [42, 17])
        let outcome = try LuaRuntime.run(
            "return { first = config.accounts[1], count = #config.accounts, key = config.api_key }", config: config
        )
        #expect(outcome.value.tableValue?["first"]?.intValue == 42)
        #expect(outcome.value.tableValue?["count"]?.intValue == 2)
        #expect(outcome.value.tableValue?["key"]?.stringValue == "Production")
        #expect(try LuaRuntime.run("return #config.accounts").value.intValue == 0)
        #expect(try LuaRuntime.run("return config.api_key == nil").value.boolValue == true)
        _ = try LuaRuntime.run("config.accounts[1] = 999", config: config)
        #expect(try LuaRuntime.run("return config.accounts[1]", config: config).value.intValue == 42)
    }

    @Test func documentVariablesAreConfigFieldsOnly() throws {
        let config = try NrqlConnection.parseDocumentConfig("""
            /***
            var appName = "Foo"
            var: title = config.appName .. " report"
            var filter = { enabled = true, ids = {42, 17} }
            ***/
            """)
        let value = try LuaRuntime.run(
            "return { name = config.appName, title = config.title, id = config.filter.ids[1], enabled = config.filter.enabled }",
            config: config
        ).value
        #expect(value.tableValue?["name"]?.stringValue == "Foo")
        #expect(value.tableValue?["title"]?.stringValue == "Foo report")
        #expect(value.tableValue?["id"]?.intValue == 42)
        #expect(value.tableValue?["enabled"]?.boolValue == true)
        #expect(try LuaRuntime.run("return appName == nil and filter == nil", config: config).value.boolValue == true)
        #expect(throws: (any Error).self) {
            try LuaRuntime.run("return config.appName", config: NrqlConnection(variables: [
                .init(name: "appName", expression: "missing.value")
            ]))
        }
    }

    @Test(arguments: ["var:", "var accounts = {}", "var api_key = {}", "var bad-name = 1", "var appName =", "var appName = 1\nvar appName = 2"])
    func rejectsInvalidDocumentDeclarations(_ declaration: String) {
        #expect(throws: NrqlConnection.ConfigurationError.self) {
            try NrqlConnection.parseDocumentConfig("/***\n\(declaration)\n***/")
        }
    }

    @Test func sandboxRemovesIOAndLoad() throws {
        #expect(try LuaRuntime.run("return io == nil").value.boolValue == true)
        #expect(try LuaRuntime.run("return load == nil").value.boolValue == true)
        #expect(try LuaRuntime.run("return os.execute == nil").value.boolValue == true)
    }

    @Test func stopsRunawayLoops() {
        #expect(throws: LuaError.self) { try LuaRuntime.run("while true do end") }
    }

    @Test func limitsMemory() {
        #expect(throws: LuaError.self) {
            try LuaRuntime.run("local t = {} for i = 1, 1e9 do t[i] = {i} end return #t")
        }
    }

    @Test func reportsSyntaxErrors() {
        #expect(throws: LuaError.self) { try LuaRuntime.run("not valid lua") }
    }

    // MARK: - Result bridge

    private func container(results: String, facets: String = "null") throws -> NrdbResultContainer {
        let json = #"{"nrql":"SELECT 1","results":\#(results),"metadata":{"facets":\#(facets),"timeWindow":null}}"#
        return try JSONDecoder().decode(NrdbResultContainer.self, from: Data(json.utf8))
    }

    @Test func bridgesResultsToLuaAndBack() throws {
        let original = try container(
            results: """
            [
              {"beginTimeSeconds":100,"endTimeSeconds":160,"facet":"a","count":1,"host":"x","bins":[1,2]},
              {"beginTimeSeconds":160,"endTimeSeconds":220,"facet":"b","count":2,"host":"y","bins":[3]}
            ]
            """,
            facets: #"["appName"]"#
        )

        let outcome = try LuaRuntime.run(
            "emit(results.first)", results: [.init(name: "first", value: LuaResultBridge.luaValue(from: original))]
        )
        let copy = try LuaResultBridge.container(from: outcome.value)

        #expect(copy.nrql == "SELECT 1")
        #expect(copy.metadata.facets == ["appName"])
        #expect(copy.data.count == 2)
        #expect(copy.isTimeseries && copy.isFaceted)
        #expect(copy.data[1].facet == "b")
        #expect(copy.data[1].numberFields["count"] == 2)
        #expect(copy.data[0].stringFields["host"] == "x")
        #expect(copy.data[0].numericArrayFields["bins"] == [1, 2])
        #expect(Set(copy.fieldNames) == Set(original.fieldNames))
    }

    @Test func scriptsReadPriorResultsByNameAndIndex() throws {
        let value = LuaResultBridge.luaValue(from: try container(results: #"[{"count":7},{"count":9}]"#))
        let prior = [LuaRuntime.PriorResult(name: "totals", value: value)]

        #expect(try LuaRuntime.run("return results.totals.rows[2].count", results: prior).value.intValue == 9)
        #expect(try LuaRuntime.run("return results[1].rows[1].count", results: prior).value.intValue == 7)
        #expect(try LuaRuntime.run("return results.missing == nil", results: prior).value.boolValue == true)
    }

    @Test func scriptsCannotModifyResults() {
        let prior = [LuaRuntime.PriorResult(name: "x", value: .table([:]))]
        #expect(throws: LuaError.self) { try LuaRuntime.run("results.x = 1", results: prior) }
    }

    @Test func scriptBuiltRowsBecomeAChartableResult() throws {
        let outcome = try LuaRuntime.run("""
        local rows = {}
        for i = 1, 3 do rows[#rows + 1] = { facet = i, total = i * 10 } end
        emit({ rows = rows })
        """)
        let result = try LuaResultBridge.container(from: outcome.value)

        #expect(result.isFaceted)
        #expect(result.allFacets == ["1", "2", "3"])
        #expect(result.numberFieldNames.contains("total"))
    }

    @Test func acceptsBareRowListsAndEmptyResults() throws {
        let bare = try LuaRuntime.run("emit({ { count = 1 }, { count = 2 } })")
        #expect(try LuaResultBridge.container(from: bare.value).data.count == 2)

        let empty = try LuaRuntime.run("emit({ rows = {} })")
        #expect(try LuaResultBridge.container(from: empty.value).data.isEmpty)
    }

    @Test func rejectsValuesThatAreNotResults() throws {
        #expect(throws: LuaResultBridge.BridgeError.self) {
            try LuaResultBridge.container(from: try LuaRuntime.run("return 5").value)
        }
        #expect(throws: LuaResultBridge.BridgeError.self) {
            try LuaResultBridge.container(from: try LuaRuntime.run("return { rows = { 1, 2 } }").value)
        }
    }
}
