//
//  NrqlCompletionTests.swift
//  NR StatusTests
//

import Testing
import Foundation
@testable import NR_Status

struct NerdgraphCompletionTests {
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

    @Test func completesNativeMetadataKeysAndSavedKeyNames() async {
        let profiles = [NerdgraphProfile(name: "Production US"), NerdgraphProfile(name: "Staging")]
        let text = "# A note\n\n  # va"
        let keys = await NrqlCompletion.items(
            text: text, location: text.utf16.count, metadata: NrqlCompletionTests.StubMetadata(),
            profiles: profiles, configuration: true, graphql: true
        )
        #expect(keys.items.map(\.name) == ["var"])
        #expect(keys.items.first?.insertText == "var: ")
        #expect(keys.range == NSRange(location: text.utf16.count - 2, length: 2))
        let value = "# title: Details\n# api-key: Production U"
        let names = await NrqlCompletion.items(
            text: value, location: value.utf16.count, metadata: NrqlCompletionTests.StubMetadata(),
            profiles: profiles, configuration: true, graphql: true
        )
        #expect(names.items.map(\.name) == ["Production US"])
        #expect((value as NSString).substring(with: names.range) == "Production U")
        for query in ["{ actor {\n# var: ", "/***\nvar: "] {
            #expect(NrqlCompletion.analyse(text: query, location: query.utf16.count, configuration: true, graphql: true).context == .none)
        }
        let chart = "# chart: "
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
        #expect(await names("/***\n  va|\n***/") == ["var"])
        #expect(await names("/***\n  na|\n***/").isEmpty)
        #expect(await names("/***\nchart: p|\n***/") == ["pie", "plot"])
        #expect(await names("/***\nchart: j|\n***/") == ["json"])
        #expect(await names("/***\nchart: pie\nattributes: |\n***/") == ["donut", "separated"])
        #expect(await names("/***\nchart: plot\nattributes: x-|\n***/") == ["x-log"])
        #expect(await names("/***\ntitle: Fo|\n***/").isEmpty)
    }

    @Test func completesSavedNamesAndOnlyTheSelectedKeysPreferredAccounts() async {
        let profiles = [
            NerdgraphProfile(name: "Production US", preferredAccountIds: [123, 456]),
            NerdgraphProfile(name: "Staging", preferredAccountIds: [789])
        ]
        func complete(_ text: String, configuration: Bool = false) async -> (items: [NrqlCompletion.Item], range: NSRange) {
            await NrqlCompletion.items(text: text, location: text.utf16.count, metadata: StubMetadata(),
                                       profiles: profiles, defaultKeyName: "Production US", configuration: configuration)
        }
        let keyText = "/***\napi-key: Production U"
        let key = await complete(keyText)
        #expect(key.items.map(\.name) == ["Production US"])
        #expect((keyText as NSString).substring(with: key.range) == "Production U")
        #expect(await complete("/***\naccounts: ").items.map(\.name) == ["123", "456"])
        #expect(await complete("/***\napi-key: Staging\naccounts: ").items.map(\.name) == ["789"])
        #expect(await complete("/***\napi-key: Unknown\naccounts: ").items.isEmpty)
        #expect(await complete("/***\naccounts: 123, 4").items.map(\.name) == ["456"])
        #expect(await complete("/***\napi-key: Staging\naccounts: ", configuration: true).items.map(\.name) == ["789"])
        #expect(await complete("/***\nacc", configuration: true).items.map(\.name) == ["accounts"])
        #expect(await complete("/***\naut", configuration: true).items.map(\.name) == ["author"])
        #expect(await complete("/***\ndesc", configuration: true).items.map(\.name) == ["description"])
        #expect(await complete("accounts: ", configuration: true).items.isEmpty)
        #expect(await complete("// api-key: ", configuration: true).items.isEmpty)
        #expect(await complete("/***\napi-key: Staging\n***/\naccounts: ", configuration: true).items.isEmpty)
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
