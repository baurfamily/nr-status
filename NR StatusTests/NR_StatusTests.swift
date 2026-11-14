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
