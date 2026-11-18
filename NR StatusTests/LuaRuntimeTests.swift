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
            bindings:
              - name: appName
                expression: '"Foo"'
              - name: title
                expression: config.appName .. " report"
              - name: filter
                expression: '{ enabled = true, ids = {42, 17} }'
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

    @Test(arguments: [
        "bindings: [{name: appName, value: Foo, expression: 1}]",
        "bindings: [{name: appName, value: [Foo]}]",
        "bindings: [{name: accounts, value: Foo}]",
        "bindings: [{name: bad-name, value: Foo}]",
        "bindings:",
        "bindings: [appName]",
        "bindings: {appName: 1}",
        "bindings: [{name: accounts, expression: '{}'}]",
        "bindings: [{name: api_key, expression: '{}'}]",
        "bindings: [{name: bad-name, expression: 1}]",
        "bindings: [{name: return, expression: 1}]",
        "bindings: [{name: appName}]",
        "bindings: [{name: appName, expression: ''}]",
        "bindings: [{name: appName, expression: 1, extra: 2}]",
        "bindings: [{name: appName, expression: 1}, {name: appName, expression: 2}]",
        "var: appName = 1"
    ])
    func rejectsInvalidDocumentBindings(_ configuration: String) {
        #expect(throws: (any Error).self) {
            try NrqlConnection.parseDocumentConfig(configuration)
        }
    }

    @Test(arguments: ["Checkout", "", "42", "true", "config.accounts[1]", "'quoted' \"text\"\\path\n  next line\n"])
    func literalBindingsPreserveStringsWithoutEvaluatingLua(_ literal: String) throws {
        let body = try LuaRuntime.Variable.updatingBindings([
            .init(name: "label", value: literal),
            .init(name: "heading", expression: "config.label .. '!'")
        ], in: "")
        let config = try NrqlConnection.parseDocumentConfig(body)
        #expect(config.variables[0].value == literal)
        #expect(config.variables[0].expression == nil && !config.variables[0].isWholeResponse)
        let output = try LuaRuntime.run(
            "return { label = config.label, heading = config.heading, kind = type(config.label) }", config: config
        ).value
        #expect(output.tableValue?["label"]?.stringValue == literal)
        #expect(output.tableValue?["heading"]?.stringValue == literal + "!")
        #expect(output.tableValue?["kind"]?.stringValue == "string")
    }

    @Test func literalYAMLScalarsBecomeStrings() throws {
        for (scalar, expected) in [("42", "42"), ("true", "true"), ("null", ""), ("\"null\"", "null"), ("\"\"", "")] {
            let config = try NrqlConnection.parseDocumentConfig("bindings: [{name: label, value: \(scalar)}]")
            #expect(try LuaRuntime.run("return config.label", config: config).value.stringValue == expected)
            #expect(try LuaRuntime.run("return type(config.label)", config: config).value.stringValue == "string")
        }
    }

    @Test func documentBindingsCanBeEmptyAndUseTheSameRecordsAsGraphQL() throws {
        #expect(try NrqlConnection.parseDocumentConfig("bindings: []").variables.isEmpty)
        let configuration = """
            bindings:
              - name: threshold
                expression: 10
              - name: doubled
                expression: config.threshold * 2
            """
        let documentBindings = try NrqlConnection.parseDocumentConfig(configuration).variables
        let cell = NerdgraphCellSource(stored: "```cell_config\n\(configuration)\n```\n```graphql\n{}\n```")
        #expect(try cell.resultBindings() == documentBindings)
        #expect(try LuaRuntime.run("return config.doubled", config: .init(variables: documentBindings)).value.intValue == 20)
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

    private func busiestAppRegressionScript() throws -> String {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("docs/examples/BusiestApp.nrmd")
        let document = NRQL_EditorDocument(text: try String(contentsOf: url, encoding: .utf8))
        let cell = try #require(document.cells.first {
            $0.query.title == "Metrics for the busiest app with regression"
        })
        #expect(document.pendingDependencies(for: cell.id, stale: []).map(\.query.title) == [
            "Busiest app, last week", "Metrics for the busiest app"
        ])
        return try #require(cell.query.script)
    }

    @Test func busiestAppSampleFitsAndChartsOnlyCurrentPeriod() throws {
        let source = try container(results: """
        [
          {"beginTimeSeconds":1700000000,"endTimeSeconds":1700086400,"comparison":"current","count":10},
          {"beginTimeSeconds":1700086400,"endTimeSeconds":1700172800,"comparison":"current","count":24},
          {"beginTimeSeconds":1700172800,"endTimeSeconds":1700259200,"comparison":"current","count":26},
          {"beginTimeSeconds":1697408000,"endTimeSeconds":1697494400,"comparison":"previous","count":100},
          {"beginTimeSeconds":1697580800,"endTimeSeconds":1697667200,"comparison":"previous","count":60},
          {"beginTimeSeconds":1697667200,"endTimeSeconds":1697753600,"comparison":"previous","count":40}
        ]
        """)
        let outcome = try LuaRuntime.run(
            busiestAppRegressionScript(),
            results: [.init(name: "busiest_metrics", value: LuaResultBridge.luaValue(from: source))]
        )
        let result = try LuaResultBridge.container(from: outcome.value)

        let current = source.data.filter { $0.comparison == .current }
        #expect(result.data.map { $0.numberFields["Regression"] } == [12, 20, 28])
        #expect(result.data.map(\.beginTime) == current.map(\.beginTime))
        #expect(result.data.map(\.endTime) == current.map(\.endTime))
        #expect(!result.isComparable)
        #expect(result.data.map { $0.numberFields["count"] } == current.map { $0.numberFields["count"] })
        #expect(source.data.count == 6)
        #expect(source.data.allSatisfy { $0.numberFields["Regression"] == nil })
        #expect(ChartType.cases(for: result).contains(.line))
    }

    @Test func busiestAppSampleFitsConstantCountsWithoutComparison() throws {
        let source = try container(results: """
        [
          {"beginTimeSeconds":1000,"endTimeSeconds":1060,"count":7},
          {"beginTimeSeconds":1060,"endTimeSeconds":1120,"count":7}
        ]
        """)
        let outcome = try LuaRuntime.run(
            busiestAppRegressionScript(),
            results: [.init(name: "busiest_metrics", value: LuaResultBridge.luaValue(from: source))]
        )
        let result = try LuaResultBridge.container(from: outcome.value)
        #expect(result.data.map { $0.numberFields["Regression"] } == [7, 7])
        #expect(!result.isComparable)
    }

    @Test(arguments: [
        "[]",
        #"[{"beginTimeSeconds":1000,"endTimeSeconds":1060,"count":1}]"#,
        #"[{"beginTimeSeconds":1000,"endTimeSeconds":1060,"count":1},{"beginTimeSeconds":1000,"endTimeSeconds":1060,"count":2}]"#,
        #"[{"beginTimeSeconds":1000,"endTimeSeconds":1060,"comparison":"current","count":1},{"beginTimeSeconds":400,"endTimeSeconds":460,"comparison":"previous","count":2}]"#,
        #"[{"beginTimeSeconds":400,"endTimeSeconds":460,"comparison":"previous","count":1},{"beginTimeSeconds":460,"endTimeSeconds":520,"comparison":"previous","count":2}]"#
    ])
    func busiestAppSampleRejectsInsufficientTimeBuckets(_ rows: String) throws {
        let script = try busiestAppRegressionScript()
        let source = try container(results: rows)
        #expect(throws: LuaError.self) {
            try LuaRuntime.run(
                script,
                results: [.init(name: "busiest_metrics", value: LuaResultBridge.luaValue(from: source))]
            )
        }
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
