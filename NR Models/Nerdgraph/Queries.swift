//
//  Queries.swift
//  NR Status
//
//  Created by Eric Baur on 9/22/24.
//

import Foundation

struct Queries {
    static let defaultNrqlTimeout = 30

    enum NrqlError: LocalizedError {
        case timedOut(Int)
        case requestTimedOut

        var errorDescription: String? {
            switch self {
            case .timedOut(let seconds):
                return "The NRQL query timed out after \(seconds) seconds without returning results. Increase timeout in Cell Configuration > Text (for example, timeout: 120) and run it again."
            case .requestTimedOut:
                return "The NRQL request timed out before results were received. Try again, or increase timeout in Cell Configuration > Text (for example, timeout: 120)."
            }
        }
    }

    enum EntityDetail {
        case basic
        case full
    }

    private struct NrqlVariables: Encodable {
        let accountIds: [Int]
        let nrql: String
    }

    private struct EntitySearchVariables: Encodable {
        let sortType: [String]
        let nrql: String
    }

    let config: NerdgraphConfig
    private let client: NerdgraphClient

    init(config: NerdgraphConfig, session: URLSession = .shared) {
        self.config = config
        self.client = NerdgraphClient(config: config, session: session)
    }

    /// Any value passed here overrides the stored preference (used by widgets,
    /// which carry their own credentials).
    init(host: String? = nil, apiKey: String? = nil, accountIds: String? = nil) {
        var config = NerdgraphConfig.current
        if let host { config.host = host }
        if let apiKey { config.apiKey = apiKey }
        if let accountIds { config.accountIds = accountIds }

        self.config = config
        self.client = NerdgraphClient(config: config)
    }

    func user(debug: Bool = false) async throws -> User? {
        let root = try await client.send(GraphQLDocuments.user, debug: debug)
        return root.data?.actor?.user
    }

    func accounts(debug: Bool = false) async throws -> [Account]? {
        let root = try await client.send(GraphQLDocuments.accounts, debug: debug)
        return root.data?.actor?.accounts
    }

    func getNrqlData(
        query nrql: String, timeout: Int = Self.defaultNrqlTimeout, debug: Bool = false
    ) async throws -> NrdbResultContainer? {
        let variables = NrqlVariables(accountIds: config.accountIdList, nrql: nrql)
        do {
            let root = try await client.send(
                GraphQLDocuments.nrql(timeout: timeout), variables: variables, debug: debug,
                timeoutInterval: max(NerdgraphClient.requestTimeoutInterval, TimeInterval(timeout) + 30)
            )
            if let result = root.data?.actor?.nrql { return result }
            if let errors = root.errors, !errors.isEmpty {
                throw NerdgraphClient.ClientError.graphQL(errors.map(\.message))
            }
            return nil
        } catch NerdgraphClient.ClientError.graphQL(let messages) where messages.contains(where: {
            let message = $0.lowercased()
            return ["timeout", "timed out", "time limit", "deadline exceeded"].contains { message.contains($0) }
        }) {
            throw NrqlError.timedOut(timeout)
        } catch let error as URLError where error.code == .timedOut {
            throw NrqlError.requestTimedOut
        }
    }

    func entities(domain: Entity.Domain, detail: EntityDetail = .full, debug: Bool = false) async throws -> [Entity]? {
        // account IDs are parsed to integers, so this is safe to interpolate
        var clauses = ["alertable IS TRUE"]
        let ids = config.accountIdList
        if !ids.isEmpty {
            clauses.append("accountId IN ( \(ids.map(String.init).joined(separator: ", ")) )")
        }
        clauses.append("domain = '\(domain.rawValue)'")

        let variables = EntitySearchVariables(
            sortType: ["REPORTING", "ALERT_SEVERITY", "NAME"],
            nrql: "(" + clauses.joined(separator: " AND ") + ")"
        )
        let document = detail == .full ? GraphQLDocuments.fullEntitySearch : GraphQLDocuments.basicEntitySearch

        let root = try await client.send(document, variables: variables, debug: debug)
        return root.data?.actor?.entitySearch?.results?.entities
    }
}
