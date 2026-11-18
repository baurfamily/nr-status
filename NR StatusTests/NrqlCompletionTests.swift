//
//  NrqlCompletionTests.swift
//  NR StatusTests
//

import Testing
import Foundation
@testable import NR_Status

struct NerdgraphCompletionTests {
    @Test func completesChartHeightInLines() async {
        let keys = await NrqlCompletion.items(
            text: "hei", location: 3, metadata: NrqlCompletionTests.StubMetadata(), configuration: true
        )
        #expect(keys.items.map(\.insertText) == ["height: "])
        let values = await NrqlCompletion.items(
            text: "height: ", location: 8, metadata: NrqlCompletionTests.StubMetadata(), configuration: true
        )
        #expect(Set(values.items.map(\.name)) == ["auto", "20"])
    }

    private func schema() throws -> NerdgraphSchema {
        try JSONDecoder().decode(NerdgraphSchema.self, from: Data("""
            {
              "queryType": {"name": "Query"},
              "mutationType": {"name": "Mutation"},
              "types": [
                {"name": "Query", "kind": "OBJECT", "fields": [
                  {"name": "actor", "description": "Current actor", "args": [], "type": {"kind": "OBJECT", "name": "Actor"}}
                ]},
                {"name": "Actor", "kind": "OBJECT", "fields": [
                  {"name": "user", "args": [], "type": {"kind": "OBJECT", "name": "User"}},
                  {"name": "account", "args": [
                    {"name": "id", "description": "Account ID", "type": {"kind": "NON_NULL", "ofType": {"kind": "SCALAR", "name": "Int"}}},
                    {"name": "locale", "type": {"kind": "SCALAR", "name": "String"}}
                  ], "type": {"kind": "OBJECT", "name": "Account"}}
                ]},
                {"name": "User", "kind": "OBJECT", "fields": [
                  {"name": "name", "description": "Display name", "args": [], "type": {"kind": "SCALAR", "name": "String"}},
                  {"name": "email", "args": [], "type": {"kind": "SCALAR", "name": "String"}}
                ]},
                {"name": "Account", "kind": "OBJECT", "fields": [
                  {"name": "name", "args": [], "type": {"kind": "SCALAR", "name": "String"}}
                ]},
                {"name": "Mutation", "kind": "OBJECT", "fields": [
                  {"name": "update", "args": [], "type": {"kind": "OBJECT", "name": "User"}}
                ]},
                {"name": "Filter", "kind": "INPUT_OBJECT", "inputFields": [
                  {"name": "enabled", "description": "Enable entity lookup", "type": {"kind": "SCALAR", "name": "Boolean"}}
                ]},
                {"name": "String", "kind": "SCALAR", "description": "Text values"}
              ]
            }
            """.utf8))
    }

    @Test(arguments: [
        "{ actor { user { na",
        "{ me: actor { alias: user { na",
        "{ actor { account(id: 1) { na",
        "{ actor { account(id: {nested: \"}\"}) { na",
        "{ actor { user { ... on User { na",
        "fragment Details on User { na",
        "mutation Update { update { na",
        "# 😀 ignored braces { }\n{ actor { user { na"
    ])
    func completesNestedFieldsWithoutConfusingAliasesArgumentsOrFragments(text: String) throws {
        let completion = NerdgraphCompletion.items(text: text, location: text.utf16.count, schema: try schema())
        #expect(completion.items.map(\.name) == ["name"])
        #expect(completion.range == NSRange(location: text.utf16.count - 2, length: 2))
    }

    @Test func suggestsArgumentsAndDeclaredVariables() throws {
        let schema = try schema()
        let text = "{ actor { account(i"
        let found = NerdgraphCompletion.items(text: text, location: text.utf16.count, schema: schema)
        #expect(found.items.first?.insertText == "id: ")
        #expect(found.items.first?.detail?.contains("Int!") == true)
        let variable = "query($accountId: Int!) { actor { account(id: $acc"
        let variables = NerdgraphCompletion.items(text: variable, location: variable.utf16.count, schema: schema)
        #expect(variables.items.map(\.name) == ["accountId"])
        #expect(variables.items.first?.insertText == "accountId")
    }

    @Test(arguments: [
        "{ actor { # us",
        "{ actor { account(id: \"na",
        "{ actor { account(id: \"\"\"na",
        "{ actor { # title: na"
    ])
    func doesNotOfferFieldsInsideCommentsOrStrings(text: String) throws {
        #expect(NerdgraphCompletion.items(text: text, location: text.utf16.count, schema: try schema()).items.isEmpty)
    }

    @Test func includesSchemaDocumentation() throws {
        let text = "{ actor { user { na"
        let found = NerdgraphCompletion.items(text: text, location: text.utf16.count, schema: try schema())
        #expect(found.items.first?.detail?.contains("Display name") == true)
    }

    @Test func completesPlainNerdgraphConfigurationKeysAndSavedKeyNames() async {
        let profiles = [NerdgraphProfile(name: "Production US"), NerdgraphProfile(name: "Staging")]
        let text = "  va"
        let keys = await NrqlCompletion.items(
            text: text, location: text.utf16.count, metadata: NrqlCompletionTests.StubMetadata(),
            profiles: profiles, configuration: true, graphql: true
        )
        #expect(keys.items.map(\.name) == ["var"])
        #expect(keys.items.first?.insertText == "var: ")
        #expect(keys.range == NSRange(location: text.utf16.count - 2, length: 2))
        for graphql in [true, false] {
            let bindings = await NrqlCompletion.items(
                text: "bin", location: 3, metadata: NrqlCompletionTests.StubMetadata(),
                configuration: true, graphql: graphql
            )
            #expect(bindings.items.map(\.insertText) == ["bindings: "])
        }
        let value = "title: Details\napi-key: Production U"
        let names = await NrqlCompletion.items(
            text: value, location: value.utf16.count, metadata: NrqlCompletionTests.StubMetadata(),
            profiles: profiles, configuration: true, graphql: true
        )
        #expect(names.items.map(\.name) == ["Production US"])
        #expect((value as NSString).substring(with: names.range) == "Production U")
        for query in ["# var: ", "/***\nvar: "] {
            #expect(NrqlCompletion.analyse(text: query, location: query.utf16.count, configuration: true, graphql: true).context == .none)
        }
        let chart = "chart: "
        let charts = await NrqlCompletion.items(
            text: chart, location: chart.utf16.count, metadata: NrqlCompletionTests.StubMetadata(),
            configuration: true, graphql: true
        )
        #expect(charts.items.map(\.name) == ["json", "none"])
    }

    @Test func documentationFollowsFieldsArgumentsAndSelectionTypes() throws {
        let schema = try schema()
        let cases: [(String, NerdgraphSchema.DocumentationTarget)] = [
            ("{ actor { us|er { name } } }", .init(typeName: "Actor", fieldName: "user")),
            ("{ alias: actor { user { na|me } } }", .init(typeName: "User", fieldName: "name")),
            ("{ actor { account(i|d: 42) { name } } }", .init(typeName: "Actor", fieldName: "account", argumentName: "id")),
            ("{ actor { account(id: |42) { name } } }", .init(typeName: "Actor", fieldName: "account", argumentName: "id")),
            ("{ actor { account(id: 42 loc|ale : \"en\") { name } } }", .init(typeName: "Actor", fieldName: "account", argumentName: "locale")),
            ("{ actor { account(id: 42, loc|ale: \"en\") { name } } }", .init(typeName: "Actor", fieldName: "account", argumentName: "locale")),
            ("{ actor { user { | } } }", .init(typeName: "User")),
            ("{ actor { user { ... on Us|er { name } } } }", .init(typeName: "User")),
            ("mutation { up|date { name } }", .init(typeName: "Mutation", fieldName: "update")),
            ("# 😀 notes\n{ actor { user { nam|e } } }", .init(typeName: "User", fieldName: "name"))
        ]
        for (marked, expected) in cases {
            let location = (marked as NSString).range(of: "|").location
            let text = marked.replacingOccurrences(of: "|", with: "")
            #expect(NerdgraphCompletion.documentationTarget(text: text, location: location, schema: schema) == expected)
        }
    }

    @Test func documentationSearchCoversAllTypesFieldsArgumentsAndDescriptions() throws {
        let schema = try schema()
        #expect(schema.documentationMatches("Display name") == [.init(typeName: "User", fieldName: "name")])
        #expect(schema.documentationMatches("Account ID") == [.init(typeName: "Actor", fieldName: "account", argumentName: "id")])
        #expect(schema.documentationMatches("entity lookup") == [.init(typeName: "Filter", fieldName: "enabled")])
        #expect(schema.documentationMatches("TEXT VALUES") == [.init(typeName: "String")])
        #expect(schema.documentationMatches("").contains(.init(typeName: "Filter")))
        #expect(schema.documentationMatches("missing documentation").isEmpty)
    }
}

struct NrqlCompletionTests {
    struct StubMetadata: NrqlMetadataProviding {
        func eventTypes() async -> [String] { ["Transaction", "TransactionError", "PageView"] }
        func attributes(event: String) async -> [Attribute] {
            event == "Transaction"
                ? [Attribute(event: event, type: "string", key: "name"), Attribute(event: event, type: "numeric", key: "duration"),
                   Attribute(event: event, type: "string", key: "weird key")]
                : []
        }

        func values(for lookup: NrqlValueCompletion.Lookup) async -> [String] {
            lookup.event == "Transaction" && lookup.attribute == "name"
                ? ["Checkout", "Checkout API", "O'Brien", "C:\\services\\api", "😀 Checkout", "a//b"] : []
        }
    }

    /// `|` marks the cursor.
    private func names(_ marked: String) async -> [String] {
        let location = (marked as NSString).range(of: "|").location
        let text = marked.replacingOccurrences(of: "|", with: "")
        return await NrqlCompletion.items(text: text, location: location, metadata: StubMetadata()).items.map(\.name)
    }

    @Test(arguments: [
        "SELECT count(*) FROM Transaction WHERE name = '|",
        "FROM Transaction SELECT count(*) WHERE name != 'Ch|",
        "SELECT count(*) FROM Transaction WHERE name <> 'Ch|'",
        "SELECT count(*) FROM Transaction WHERE name IN ('Ch|')",
        "SELECT count(*) FROM Transaction WHERE name NOT IN ('Other',\n'Ch|')",
        "SELECT count(*) FROM Transaction WHERE (name = 'Ch|')",
        "SELECT count(*) FROM Transaction WHERE duration > 1 AND name = 'Ch|'"
    ])
    func completesStringComparisonsAndLists(_ marked: String) async {
        let found = await names(marked)
        #expect(found.contains("Checkout"))
        #expect(found.contains("Checkout API"))
        #expect(!found.contains("duration"))
    }

    @Test(arguments: [
        ("", "SINCE 1 hour ago"),
        ("SINCE 2 days ago UNTIL 1 day ago", "SINCE 2 days ago UNTIL 1 day ago"),
        ("UNTIL 2 hours ago", "SINCE 10800000 milliseconds ago UNTIL 2 hours ago"),
        ("SINCE today WITH TIMEZONE 'America/Los_Angeles'", "SINCE today WITH TIMEZONE 'America/Los_Angeles'")
    ])
    func valueDocumentationShowsTheLookupScopeWithoutChangingRowDetails(_ suffix: String, _ expected: String) async throws {
        let text = "FROM Transaction SELECT count(*) WHERE name = '' \(suffix)"
        let location = (text as NSString).range(of: "''").location + 1
        let found = await NrqlCompletion.items(text: text, location: location, metadata: StubMetadata())
        let completion = try #require(found.items.first)
        #expect(completion.detail == nil)
        #expect(completion.documentationText.hasPrefix("Transaction.name\n\n"))
        #expect(completion.documentationText.contains("\n\n\(expected)\n\n"))
    }

    @Test func replacesTheWholeLiteralWithoutDuplicatingQuotesAndEscapesValues() async throws {
        for (marked, expected) in [
            ("SELECT count(*) FROM Transaction WHERE name = 'O|", #"name = 'O\'Brien'"#),
            ("SELECT count(*) FROM Transaction WHERE name = 'O\\'|'", #"name = 'O\'Brien'"#),
            ("SELECT count(*) FROM Transaction WHERE name = 'Che|obsolete'", "name = 'Checkout'"),
            ("SELECT count(*) FROM Transaction WHERE name = 'C:|'", #"name = 'C:\\services\\api'"#),
            ("SELECT count(*) FROM Transaction WHERE name = '😀|'", "name = '😀 Checkout'"),
            ("SELECT count(*) FROM Transaction WHERE name = 'a//|'", "name = 'a//b'")
        ] {
            let location = (marked as NSString).range(of: "|").location
            let text = marked.replacingOccurrences(of: "|", with: "")
            let found = await NrqlCompletion.items(text: text, location: location, metadata: StubMetadata())
            let completion = try #require(found.items.first)
            #expect((text as NSString).replacingCharacters(in: found.range, with: completion.insertText).hasSuffix(expected))
        }
    }

    @Test(arguments: [
        ("", "SINCE 1 hour ago"),
        ("SINCE 30 minutes ago", "SINCE 30 minutes ago"),
        ("SINCE 2 days ago UNTIL 1 day ago", "SINCE 2 days ago UNTIL 1 day ago"),
        ("SINCE '2026-01-01' UNTIL '2026-01-02T03:00:00Z'", "SINCE '2026-01-01' UNTIL '2026-01-02T03:00:00Z'"),
        ("SINCE 1702899296789 UNTIL 1702902896789", "SINCE 1702899296789 UNTIL 1702902896789"),
        ("UNTIL 1702902896789", "SINCE 1702899296789 UNTIL 1702902896789"),
        ("UNTIL 2 hours ago", "SINCE 10800000 milliseconds ago UNTIL 2 hours ago"),
        ("UNTIL now", "SINCE 3600000 milliseconds ago UNTIL now"),
        ("SINCE this week", "SINCE this week"),
        ("SINCE monday", "SINCE monday"),
        ("SINCE yesterday AT '01:23:45'", "SINCE yesterday AT '01:23:45'"),
        ("SINCE today WITH TIMEZONE 'America/Los_Angeles'", "SINCE today WITH TIMEZONE 'America/Los_Angeles'"),
        ("SINCE 1 hour ago COMPARE WITH 1 day ago", "SINCE 1 hour ago"),
        ("SINCE 1 hour ago TIMESERIES AUTO LIMIT 10", "SINCE 1 hour ago")
    ])
    func valueLookupsUseTheQueriesTimeWindow(_ suffix: String, _ expected: String) throws {
        let marked = "SELECT count(*) FROM Transaction WHERE name = 'Ch|' \(suffix)"
        let location = (marked as NSString).range(of: "|").location
        let text = marked.replacingOccurrences(of: "|", with: "")
        let analysis = try #require(NrqlValueCompletion.analyse(text: text, location: location))
        guard case .values(let lookup, _) = analysis.context else {
            Issue.record("Expected an attribute-value context")
            return
        }
        #expect(lookup.timeWindow == expected)
        #expect(lookup.nrql == "SELECT uniques(`name`, 100) AS completionValues FROM `Transaction` \(expected)")
    }

    @Test func untilOnlyAbsoluteTimesCoverThePrecedingHour() throws {
        let text = "FROM Transaction SELECT count(*) WHERE name = '' UNTIL '2026-01-02 03:00' WITH TIMEZONE 'UTC'"
        let location = (text as NSString).range(of: "''").location + 1
        let analysis = try #require(NrqlValueCompletion.analyse(text: text, location: location))
        guard case .values(let lookup, _) = analysis.context else {
            Issue.record("Expected an attribute-value context")
            return
        }
        let start = try #require(ISO8601DateFormatter().date(from: "2026-01-02T02:00:00Z"))
        #expect(lookup.timeWindow == "SINCE \(Int64(start.timeIntervalSince1970 * 1000)) UNTIL '2026-01-02 03:00' WITH TIMEZONE 'UTC'")
    }

    @Test func untilOnlyWeekdaysUseMondayAsTheStartOfTheWeek() throws {
        let text = "FROM Transaction SELECT count(*) WHERE name = '' UNTIL this week"
        let location = (text as NSString).range(of: "''").location + 1
        let formatter = ISO8601DateFormatter()
        let now = try #require(formatter.date(from: "2026-11-18T12:00:00Z"))
        let start = try #require(formatter.date(from: "2026-11-15T23:00:00Z"))
        let analysis = try #require(NrqlValueCompletion.analyse(text: text, location: location, now: now))
        guard case .values(let lookup, _) = analysis.context else {
            Issue.record("Expected an attribute-value context")
            return
        }
        #expect(lookup.timeWindow == "SINCE \(Int64(start.timeIntervalSince1970 * 1000)) UNTIL this week")
    }

    @MainActor @Test func openingQuotesAndSpacesInsideValuesReopenCompletions() async throws {
        let service = NrqlLanguageService(metadata: StubMetadata())
        var source = ""
        var openings = 0
        service.setTextSource { source }
        service.setCompletionAction { openings += 1 }
        for value in ["'", "'Checkout ", "'https://"] {
            source = "FROM Transaction SELECT count(*) WHERE name = \(value)"
            try await service.documentDidChange(
                position: source.utf16.count - 1, changeInLength: 1, lineChange: 0,
                columnChange: 1, newText: String(value.suffix(1))
            )
        }
        #expect(openings == 3)
    }

    @Test(arguments: [
        "SINCE", "SINCE 2", "SINCE 2 hours", "UNTIL", "UNTIL '2026-01-'",
        "SINCE '2026-01-01", "SINCE 1 hour ago SINCE 2 hours ago", "WITH TIMEZONE 'unknown'",
        "UNTIL 18446744073709551615 years ago"
    ])
    func incompleteTimeWindowsDoNotStartValueLookups(_ suffix: String) async {
        #expect(await names("SELECT count(*) FROM Transaction WHERE name = 'Ch|' \(suffix)").isEmpty)
    }

    @Test(arguments: [
        "// SELECT count(*) FROM Transaction WHERE name = 'Ch|",
        "SELECT count(*) FROM Transaction -- WHERE name = 'Ch|",
        "SELECT count(*) FROM Transaction /* WHERE name = 'Ch|",
        "SELECT 'Ch|' FROM Transaction",
        "SELECT count(*) FROM Transaction WHERE duration = '1|'",
        "SELECT count(*) FROM Transaction WHERE lower(name) = 'Ch|'",
        "SELECT count(*) FROM Transaction WHERE name LIKE 'Ch|'",
        "SELECT count(*) FROM Transaction, PageView WHERE name = 'Ch|'",
        "SELECT count(*) FROM (SELECT * FROM Transaction) WHERE name = 'Ch|'"
    ])
    func unsupportedValueContextsStayQuiet(_ marked: String) async {
        #expect(await names(marked).isEmpty)
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

    @Test func completesPlainConfiguration() async {
        func complete(_ text: String) async -> [String] {
            await NrqlCompletion.items(text: text, location: text.utf16.count, metadata: StubMetadata(), configuration: true).items.map(\.name)
        }
        #expect(await complete("  ti") == ["title"])
        #expect(await complete("  va") == ["var"])
        #expect(await complete("  na").isEmpty)
        #expect(await complete("chart: p") == ["pie", "plot"])
        #expect(await complete("chart: j") == ["json"])
        #expect(await complete("chart: con") == ["console"])
        #expect(await complete("chart: pie\nattributes: ") == ["donut", "separated"])
        #expect(await complete("chart: plot\nattributes: x-") == ["x-log"])
        #expect(await complete("title: Fo").isEmpty)
    }

    @Test func completesSavedNamesAndOnlyTheSelectedKeysPreferredAccounts() async {
        let profiles = [
            NerdgraphProfile(name: "Production US", preferredAccountIds: [123, 456]),
            NerdgraphProfile(name: "Staging", preferredAccountIds: [789])
        ]
        func complete(_ text: String, configuration: Bool = true) async -> (items: [NrqlCompletion.Item], range: NSRange) {
            await NrqlCompletion.items(text: text, location: text.utf16.count, metadata: StubMetadata(),
                                       profiles: profiles, defaultKeyName: "Production US", configuration: configuration)
        }
        let keyText = "api-key: Production U"
        let key = await complete(keyText)
        #expect(key.items.map(\.name) == ["Production US"])
        #expect((keyText as NSString).substring(with: key.range) == "Production U")
        #expect(await complete("accounts: ").items.map(\.name) == ["123", "456"])
        #expect(await complete("api-key: Staging\naccounts: ").items.map(\.name) == ["789"])
        #expect(await complete("api-key: Unknown\naccounts: ").items.isEmpty)
        #expect(await complete("accounts: 123, 4").items.map(\.name) == ["456"])
        #expect(await complete("api-key: Staging\naccounts: ", configuration: true).items.map(\.name) == ["789"])
        #expect(await complete("acc", configuration: true).items.map(\.name) == ["accounts"])
        #expect(await complete("aut", configuration: true).items.map(\.name) == ["author"])
        #expect(await complete("desc", configuration: true).items.map(\.name) == ["description"])
        #expect(await complete("// api-key: ", configuration: true).items.isEmpty)
        #expect(await complete("/* api-key: Staging", configuration: true).items.isEmpty)
    }

    @Test func offersAfterSeparators() {
        func offers(_ marked: String, configuration: Bool = false) -> Bool {
            let loc = (marked as NSString).range(of: "|").location
            return NrqlCompletion.offersAfterSeparator(text: marked.replacingOccurrences(of: "|", with: ""), location: loc, configuration: configuration)
        }
        #expect(offers("chart: line\nattributes: stacked, |", configuration: true))
        #expect(offers("chart: line\nattributes: stacked |", configuration: true))
        #expect(offers("SELECT count(*), |"))
        #expect(offers("SELECT count(*) FROM |"))
        #expect(!offers("SELECT count(*) |"))
        #expect(!offers("// note, |"))
    }
}
