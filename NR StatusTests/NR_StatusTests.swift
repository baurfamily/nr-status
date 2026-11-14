//
//  NR_StatusTests.swift
//  NR StatusTests
//
//  Created by Eric Baur on 9/21/24.
//

import Testing
import Foundation
@testable import NR_Status

// Serves canned responses so the client can be exercised without a network.
final class StubURLProtocol: URLProtocol {
    nonisolated(unsafe) static var handler: ((URLRequest) -> (Int, Data))?

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        let (status, data) = Self.handler?(request) ?? (500, Data())
        let response = HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: nil)!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: data)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}

@Suite(.serialized)
struct NerdgraphClientTests {
    @MainActor @Test func multipleResultBindingsExportValuesAndReportMissingPaths() async throws {
        let suite = "NR Status extracted bindings test \(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        let profiles = NerdgraphProfiles(
            defaults: defaults, legacyStore: KeychainStore(label: suite + " legacy", accessGroup: nil),
            labelPrefix: suite, accessGroup: nil
        )
        let profile = NerdgraphProfile(name: "GraphQL")
        try profiles.save(profile, apiKey: "test-key", makeDefault: true)
        defer {
            profiles.keychain(for: profile).remove()
            defaults.removePersistentDomain(forName: suite)
        }
        let response = #"{"data":{"actor":{"entitySearch":{"results":{"entities":[{"name":"Foo","tags":[{"key":"a"},{"key":"b"}]}]}}}}}"#
        StubURLProtocol.handler = { _ in (200, Data(response.utf8)) }
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StubURLProtocol.self]
        let session = URLSession(configuration: configuration)
        defer { session.invalidateAndCancel() }
        let document = NRQL_EditorDocument(text: """
            ```graphql
            # var: response
            # var: entity = data.actor.entitySearch.results.entities[1]
            # var: tagCount = #data.actor.entitySearch.results.entities[1].tags
            { actor { entitySearch(query: "name = 'Foo'") { results { entities { name tags { key } } } } } }
            ```

            ```lua
            return { rows = { { name = results.entity.name, count = results.tagCount } } }
            ```
            """)
        let query = document.cells[0].query
        await query.getData(profiles: profiles, session: session)
        #expect(query.errorMessage == nil)
        #expect(document.priorResults.map(\.name) == ["response", "entity", "tagCount"])
        #expect(try LuaRuntime.run(
            "return response == nil and entity == nil and tagCount == nil", results: document.priorResults
        ).value.boolValue == true)
        await document.cells[1].query.getData(results: document.priorResults, profiles: profiles)
        #expect(document.cells[1].query.resultContainer?.data.first?.numberFields["count"] == 2)
        #expect(document.cells[1].query.resultContainer?.data.first?.stringFields["name"] == "Foo")
        let original = query.text
        query.text = query.text.replacingOccurrences(of: "tagCount = #data.actor.entitySearch.results.entities[1].tags",
                                                     with: "tagCount = 7")
        #expect(document.staleCellIds(profiles: try profiles.load()) == Set(document.cells.map(\.id)))
        query.text = original
        query.text = query.text.replacingOccurrences(of: "tagCount =", with: "renamedCount =")
        #expect(NrqlDependencies.dependencies(of: document.cells[1], in: document.cells).map(\.id) == [document.cells[0].id])
        #expect(document.staleCellIds(profiles: try profiles.load()) == Set(document.cells.map(\.id)))
        query.text = original
        query.text = query.text.replacingOccurrences(of: "entity = data.actor.entitySearch.results.entities[1]",
                                                     with: "entity = data.actor.entitySearch.results.entities[9]")
        await query.getData(profiles: profiles, session: session)
        #expect(query.errorMessage?.contains("Nerdgraph variable 'entity'") == true)
        #expect(query.namedResults.isEmpty)
        query.clearResults()
        #expect(query.loadedBindings == nil)
    }

    @MainActor @Test func graphqlConfigUsesDocumentAccountsRatherThanCellOverrides() async throws {
        let suite = "NR Status GraphQL config test \(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        let profiles = NerdgraphProfiles(
            defaults: defaults, legacyStore: KeychainStore(label: suite + " legacy", accessGroup: nil),
            labelPrefix: suite, accessGroup: nil
        )
        let profile = NerdgraphProfile(name: "GraphQL", preferredAccountIds: [12, 34])
        try profiles.save(profile, apiKey: "test-key", makeDefault: true)
        defer {
            profiles.keychain(for: profile).remove()
            defaults.removePersistentDomain(forName: suite)
        }
        StubURLProtocol.handler = { _ in (200, Data(#"{"data":{}}"#.utf8)) }
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StubURLProtocol.self]
        let session = URLSession(configuration: configuration)
        defer { session.invalidateAndCancel() }
        let query = NrqlQuery(from: """
            ```graphql
            # accounts: 99
            query($id: Int!) { actor { account(id: $id) { id } } }
            ```
            ```variables
            {"id": {{ config.accounts[1] }}}
            ```
            """)
        await query.getData(defaults: NrqlConnection(accountIds: [42, 17]), profiles: profiles, session: session)
        #expect(query.errorMessage == nil)
        let sent = try #require(query.executedVariables)
        #expect(try JSONDecoder().decode(JSONValue.self, from: Data(sent.utf8)) == .object(["id": .number(42)]))
        #expect(query.loadedDocumentConfig == NrqlConnection(apiKeyName: "GraphQL", accountIds: [42, 17]))
        #expect(query.loadedConnection?.accountIds.isEmpty == true)
    }

    @MainActor @Test func executesGraphqlWithNamedKeyWithoutAccountsAndPreservesPartialErrors() async throws {
        let suite = "NR Status Nerdgraph test \(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        let profiles = NerdgraphProfiles(
            defaults: defaults, legacyStore: KeychainStore(label: suite + " legacy", accessGroup: nil),
            labelPrefix: suite, accessGroup: nil
        )
        let profile = NerdgraphProfile(name: "GraphQL", host: "\(UUID().uuidString).example.com")
        try profiles.save(profile, apiKey: "test-key", makeDefault: true)
        defer {
            profiles.keychain(for: profile).remove()
            defaults.removePersistentDomain(forName: suite)
        }
        nonisolated(unsafe) var captured: URLRequest?
        let response = #"{"data":{"customField":{"id":42}},"errors":[{"message":"partial error","path":["other"]}],"extensions":{"trace":"ok"}}"#
        StubURLProtocol.handler = {
            captured = $0
            return (200, Data(response.utf8))
        }
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StubURLProtocol.self]
        let session = URLSession(configuration: configuration)
        defer { session.invalidateAndCancel() }
        let query = NrqlQuery(from: """
            ```graphql
            # api_key: GraphQL
            # var: custom
            query($id: Int!) { customField(id: $id, text: "{{ literal }}") { id } }
            ```
            ```variables
            {"id": {{ 6 * 7 }}}
            ```
            """)
        await query.getData(defaults: NrqlConnection(apiKeyName: "Unavailable"), profiles: profiles, session: session)
        #expect(query.errorMessage == nil)
        #expect(query.jsonResult?["data"]?["customField"]?["id"] == .number(42))
        #expect(query.jsonResult?.graphQLErrors == ["partial error"])
        #expect(query.jsonResult?["extensions"]?["trace"] == .string("ok"))
        #expect(query.executedNrql?.contains("{{ literal }}") == true)
        #expect(query.executedNrql?.hasPrefix("# api_key: GraphQL\n# var: custom\n") == true)
        #expect(query.loadedConnection?.accountIds.isEmpty == true)
        let request = try #require(captured)
        #expect(request.value(forHTTPHeaderField: "api-key") == "test-key")
        #expect(request.url?.host == profile.host)
        let body: Data
        if let data = request.httpBody { body = data }
        else {
            let stream = try #require(request.httpBodyStream)
            stream.open()
            defer { stream.close() }
            var data = Data()
            var buffer = [UInt8](repeating: 0, count: 1024)
            while stream.hasBytesAvailable {
                let count = stream.read(&buffer, maxLength: buffer.count)
                guard count > 0 else { break }
                data.append(contentsOf: buffer.prefix(count))
            }
            body = data
        }
        let payload = try JSONDecoder().decode(JSONValue.self, from: body)
        #expect(payload["variables"] == .object(["id": .number(42)]))
        #expect(payload["query"] == .string(try #require(query.executedNrql)))
        let sentVariables = try #require(query.executedVariables)
        #expect(try JSONDecoder().decode(JSONValue.self, from: Data(sentVariables.utf8)) == payload["variables"])
        #expect(!sentVariables.contains("{{"))
        query.text = query.text.replacingOccurrences(of: "6 * 7", with: "results.missing.id")
        #expect(query.executedVariables == sentVariables)
        await query.getData(profiles: profiles, session: session)
        #expect(query.errorMessage != nil)
        #expect(query.executedVariables == nil)
        query.text = query.text.replacingOccurrences(of: "results.missing.id", with: "6 * 7")
        await query.getData(profiles: profiles, session: session)
        #expect(query.executedVariables == sentVariables)
        query.clearResults()
        #expect(query.executedVariables == nil)
    }

    private func makeClient() -> NerdgraphClient {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StubURLProtocol.self]
        return NerdgraphClient(host: "localhost", apiKey: "apiKey", session: URLSession(configuration: configuration))
    }

    @Test func decodesResponse() async throws {
        StubURLProtocol.handler = { _ in
            (200, Data(#"{"data":{"actor":{"user":{"email":"baur@nerdgraph.com"}}}}"#.utf8))
        }

        let root = try await makeClient().send("query { actor { user { email } } }")

        #expect(root.data?.actor?.user?.email == "baur@nerdgraph.com")
    }

    @Test func sendsApiKeyAndMethod() async throws {
        nonisolated(unsafe) var captured: URLRequest?
        StubURLProtocol.handler = { request in
            captured = request
            return (200, Data(#"{"data":{}}"#.utf8))
        }

        struct Vars: Encodable { let nrql: String }
        _ = try await makeClient().send("query", variables: Vars(nrql: "SELECT 1"))

        #expect(captured?.value(forHTTPHeaderField: "api-key") == "apiKey")
        #expect(captured?.httpMethod == "POST")
    }

    @Test func sendsResolvedKeyAndMultipleAccountsAsVariables() async throws {
        nonisolated(unsafe) var captured: URLRequest?
        StubURLProtocol.handler = { request in
            captured = request
            return (200, Data(#"{"data":{}}"#.utf8))
        }
        let sessionConfig = URLSessionConfiguration.ephemeral
        sessionConfig.protocolClasses = [StubURLProtocol.self]
        let session = URLSession(configuration: sessionConfig)
        defer { session.invalidateAndCancel() }
        let config = NerdgraphConfig(host: "eu.example.com", apiKey: "selected-key", accountIds: "12,34")
        _ = try await Queries(config: config, session: session).getNrqlData(query: "SELECT count(*) FROM Log")

        let request = try #require(captured)
        #expect(request.url?.host == "eu.example.com")
        #expect(request.value(forHTTPHeaderField: "api-key") == "selected-key")
        // URLSession may move the payload into a stream before URLProtocol sees it.
        let data: Data
        if let body = request.httpBody {
            data = body
        } else {
            let stream = try #require(request.httpBodyStream)
            stream.open()
            defer { stream.close() }
            var body = Data()
            var buffer = [UInt8](repeating: 0, count: 1024)
            while stream.hasBytesAvailable {
                let count = stream.read(&buffer, maxLength: buffer.count)
                guard count > 0 else { break }
                body.append(contentsOf: buffer.prefix(count))
            }
            data = body
        }
        let json = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let variables = try #require(json["variables"] as? [String: Any])
        #expect(variables["accountIds"] as? [Int] == [12, 34])
        #expect(variables["nrql"] as? String == "SELECT count(*) FROM Log")
    }

    @Test func throwsOnHttpError() async {
        StubURLProtocol.handler = { _ in (403, Data()) }

        await #expect(throws: NerdgraphClient.ClientError.self) {
            _ = try await makeClient().send("query")
        }
    }

    @Test func completionCacheIsIsolatedByKeyHostAndAccounts() async throws {
        nonisolated(unsafe) var requestCount = 0
        StubURLProtocol.handler = { _ in
            requestCount += 1
            return (200, Data("""
                {"data":{"actor":{"nrql":{"nrql":"SHOW EVENT TYPES","metadata":{},"results":[{"eventType":"Event\(requestCount)"}]}}}}
                """.utf8))
        }
        let sessionConfig = URLSessionConfiguration.ephemeral
        sessionConfig.protocolClasses = [StubURLProtocol.self]
        let session = URLSession(configuration: sessionConfig)
        defer { session.invalidateAndCancel() }
        let metadata = NrqlMetadata(session: session)
        let original = NerdgraphConfig(host: "a.example.com", apiKey: "key-a", accountIds: "1")
        #expect(try await metadata.eventTypes(config: original) == ["Event1"])
        var changed = original
        changed.apiKey = "key-b"
        #expect(try await metadata.eventTypes(config: changed) == ["Event2"])
        changed = original
        changed.accountIds = "2"
        #expect(try await metadata.eventTypes(config: changed) == ["Event3"])
        changed = original
        changed.host = "b.example.com"
        #expect(try await metadata.eventTypes(config: changed) == ["Event4"])
        #expect(try await metadata.eventTypes(config: original) == ["Event1"])
        #expect(requestCount == 4)
    }

    @Test func schemaCacheUsesEffectiveKeyAndHostAndReportsIntrospectionErrors() async throws {
        nonisolated(unsafe) var requestCount = 0
        StubURLProtocol.handler = { _ in
            requestCount += 1
            return (200, Data(#"{"data":{"__schema":{"queryType":{"name":"Query"},"types":[]}}}"#.utf8))
        }
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StubURLProtocol.self]
        let session = URLSession(configuration: configuration)
        defer { session.invalidateAndCancel() }
        let store = NerdgraphSchemaStore(session: session)
        let config = NerdgraphConfig(host: "first.example.com", apiKey: "first-key", accountIds: "")
        #expect(try await store.schema(config: config).queryType.name == "Query")
        _ = try await store.schema(config: config)
        #expect(requestCount == 1)
        var changed = config
        changed.apiKey = "second-key"
        _ = try await store.schema(config: changed)
        changed.host = "second.example.com"
        _ = try await store.schema(config: changed)
        #expect(requestCount == 3)
        StubURLProtocol.handler = { _ in
            (200, Data(#"{"errors":[{"message":"Introspection unavailable"}]}"#.utf8))
        }
        await #expect(throws: NerdgraphClient.ClientError.self) {
            _ = try await store.schema(config: config)
        }
    }

    @Test func throwsOnGraphQLErrorWithoutData() async {
        StubURLProtocol.handler = { _ in
            (200, Data(#"{"errors":[{"message":"bad key"}]}"#.utf8))
        }

        await #expect(throws: NerdgraphClient.ClientError.self) {
            _ = try await makeClient().send("query")
        }
    }
}

struct NerdgraphConfigTests {
    @Test func parsesAccountIds() {
        let config = NerdgraphConfig(host: "h", apiKey: "k", accountIds: "123, 456,bogus,,789")
        #expect(config.accountIdList == [123, 456, 789])
    }
}
