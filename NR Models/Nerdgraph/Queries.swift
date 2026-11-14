//
//  Queries.swift
//  NR Status
//
//  Created by Eric Baur on 9/22/24.
//

import Foundation

struct Queries {
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

    func getNrqlData(query nrql: String, debug: Bool = false) async throws -> NrdbResultContainer? {
        let variables = NrqlVariables(accountIds: config.accountIdList, nrql: nrql)
        let root = try await client.send(GraphQLDocuments.nrql, variables: variables, debug: debug)
        return root.data?.actor?.nrql
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
