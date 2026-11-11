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

    @Test func throwsOnHttpError() async {
        StubURLProtocol.handler = { _ in (403, Data()) }

        await #expect(throws: NerdgraphClient.ClientError.self) {
            _ = try await makeClient().send("query")
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
