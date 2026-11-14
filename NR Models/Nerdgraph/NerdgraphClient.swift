//
//  NerdgraphClient.swift
//  NR Status
//
//  Created by Eric Baur on 9/22/24.
//

import Foundation
import os

struct NerdgraphClient {
    enum ClientError: Error, LocalizedError {
        case httpStatus(Int)
        case graphQL([String])

        var errorDescription: String? {
            switch self {
            case .httpStatus(let code): return "NerdGraph returned HTTP \(code)"
            case .graphQL(let messages): return messages.joined(separator: "; ")
            }
        }
    }

    struct EmptyVariables: Encodable {}

    private struct Payload<Variables: Encodable>: Encodable {
        let query: String
        let variables: Variables
    }

    private static let logger = Logger(subsystem: "com.baurfamily.nrstatus", category: "NerdgraphClient")

    private let url: URL
    private let apiKey: String
    private let session: URLSession

    init(config: NerdgraphConfig = .current, session: URLSession = .shared) {
        self.url = config.url
        self.apiKey = config.apiKey
        self.session = session
    }

    init(host: String, apiKey: String, session: URLSession = .shared) {
        self.init(config: NerdgraphConfig(host: host, apiKey: apiKey, accountIds: ""), session: session)
    }

    func sendResponse<Response: Decodable, Variables: Encodable>(
        _ query: String, variables: Variables, debug: Bool = false
    ) async throws -> Response {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "api-key")
        request.httpBody = try JSONEncoder().encode(Payload(query: query, variables: variables))

        if debug {
            Self.logger.debug("request query: \(query, privacy: .public)")
        }

        do {
            let (data, response) = try await session.data(for: request)

            if debug {
                Self.logger.debug("response data: \(String(decoding: data, as: UTF8.self), privacy: .public)")
            }
            if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
                throw ClientError.httpStatus(http.statusCode)
            }

            return try JSONDecoder().decode(Response.self, from: data)
        } catch {
            Self.logger.error("request failed: \(error.localizedDescription, privacy: .public)")
            throw error
        }
    }

    func send<Variables: Encodable>(_ query: String, variables: Variables, debug: Bool = false) async throws -> Root {
        let root: Root = try await sendResponse(query, variables: variables, debug: debug)
        if let errors = root.errors, !errors.isEmpty {
            let messages = errors.map(\.message)
            Self.logger.error("GraphQL errors: \(messages.joined(separator: "; "), privacy: .public)")
            if root.data == nil { throw ClientError.graphQL(messages) }
        }
        return root
    }

    func send(_ query: String, debug: Bool = false) async throws -> Root {
        try await send(query, variables: EmptyVariables(), debug: debug)
    }
}
