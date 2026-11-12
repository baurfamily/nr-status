//
//  NrqlMetadata.swift
//  NR Status
//

import Foundation

/// Fetches event types and attributes from NRDB once and keeps them for the
/// session, so completion doesn't run a query on every keystroke.
actor NrqlMetadata: NrqlMetadataProviding {
    static let shared = NrqlMetadata()

    private var cachedEvents: [String]?
    private var cachedAttributes: [String: [Attribute]] = [:]

    func eventTypes() async -> [String] {
        if let cachedEvents { return cachedEvents }
        guard let results = try? await Queries().getNrqlData(query: "SHOW EVENT TYPES since 1 day ago") else { return [] }
        let names = results.data.compactMap { $0.stringFields["eventType"] }.sorted()
        // an empty answer is more likely a failure than a truth, so try again next time
        if !names.isEmpty { cachedEvents = names }
        return names
    }

    func attributes(event: String) async -> [Attribute] {
        if let cached = cachedAttributes[event] { return cached }
        guard let results = try? await Queries().getNrqlData(query: "SELECT keyset() FROM \(event) SINCE 1 day ago") else {
            return []
        }
        let attributes = Attribute.attributes(event: event, fromKeyset: results)
        if !attributes.isEmpty { cachedAttributes[event] = attributes }
        return attributes
    }
}
