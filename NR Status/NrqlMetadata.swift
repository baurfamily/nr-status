//
//  NrqlMetadata.swift
//  NR Status
//

import Foundation
import os

/// Keeps event types and attributes per connection for the session, so completion
/// never reuses names fetched with another key, host or account selection.
actor NrqlMetadata: NrqlMetadataProviding {
    static let shared = NrqlMetadata()

    struct Source: NrqlMetadataProviding {
        let connection: Result<NrqlConnection, Error>

        func eventTypes() async -> [String] {
            do {
                return try await NrqlMetadata.shared.eventTypes(config: connection.get().resolve())
            } catch {
                NrqlMetadata.logger.error("Event completion failed: \(error.localizedDescription, privacy: .public)")
                return []
            }
        }

        func attributes(event: String) async -> [Attribute] {
            do {
                return try await NrqlMetadata.shared.attributes(event: event, config: connection.get().resolve())
            } catch {
                NrqlMetadata.logger.error("Attribute completion failed: \(error.localizedDescription, privacy: .public)")
                return []
            }
        }

        func values(for lookup: NrqlValueCompletion.Lookup) async -> [String] {
            do {
                try Task.checkCancellation()
                let values = try await NrqlMetadata.shared.values(for: lookup, config: connection.get().resolve())
                return Task.isCancelled ? [] : values
            } catch is CancellationError {
                return []
            } catch {
                NrqlMetadata.logger.error("Value completion failed: \(error.localizedDescription, privacy: .public)")
                return []
            }
        }
    }

    private static let logger = Logger(subsystem: "com.baurfamily.nrstatus", category: "Completion")
    private let session: URLSession
    private var cachedEvents: [NerdgraphConfig: [String]] = [:]
    private var cachedAttributes: [NerdgraphConfig: [String: [Attribute]]] = [:]
    private struct ValueKey: Hashable {
        let config: NerdgraphConfig
        let lookup: NrqlValueCompletion.Lookup
    }
    private var cachedValues: [ValueKey: (values: [String], loadedAt: Date)] = [:]
    private var pendingValues: [ValueKey: Task<[String], Error>] = [:]

    init(session: URLSession = .shared) {
        self.session = session
    }

    func eventTypes() async -> [String] {
        await Source(connection: .success(NrqlConnection())).eventTypes()
    }

    func attributes(event: String) async -> [Attribute] {
        await Source(connection: .success(NrqlConnection())).attributes(event: event)
    }

    func values(for lookup: NrqlValueCompletion.Lookup) async -> [String] {
        await Source(connection: .success(NrqlConnection())).values(for: lookup)
    }

    func values(for lookup: NrqlValueCompletion.Lookup, config: NerdgraphConfig) async throws -> [String] {
        try Task.checkCancellation()
        let key = ValueKey(config: config, lookup: lookup)
        if let cached = cachedValues[key], Date().timeIntervalSince(cached.loadedAt) < 300 { return cached.values }
        if let pending = pendingValues[key] { return try await pending.value }
        let session = session
        let pending = Task {
            guard let results = try await Queries(config: config, session: session).getNrqlData(query: lookup.nrql, timeout: 5) else {
                return [String]()
            }
            return Array(Set(results.data.flatMap { $0.stringArrayFields["completionValues"] ?? [] })).sorted()
        }
        pendingValues[key] = pending
        defer { pendingValues[key] = nil }
        let values = try await pending.value
        cachedValues[key] = (values, Date())
        return values
    }

    func eventTypes(config: NerdgraphConfig) async throws -> [String] {
        if let cached = cachedEvents[config] { return cached }
        guard let results = try await Queries(config: config, session: session).getNrqlData(query: "SHOW EVENT TYPES since 1 day ago") else { return [] }
        let names = results.data.compactMap { $0.stringFields["eventType"] }.sorted()
        if !names.isEmpty { cachedEvents[config] = names }
        return names
    }

    func attributes(event: String, config: NerdgraphConfig) async throws -> [Attribute] {
        if let cached = cachedAttributes[config]?[event] { return cached }
        guard let results = try await Queries(config: config, session: session).getNrqlData(query: "SELECT keyset() FROM \(event) SINCE 1 day ago") else { return [] }
        let attributes = Attribute.attributes(event: event, fromKeyset: results)
        if !attributes.isEmpty { cachedAttributes[config, default: [:]][event] = attributes }
        return attributes
    }
}
