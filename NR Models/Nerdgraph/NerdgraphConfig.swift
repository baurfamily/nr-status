//
//  NerdgraphConfig.swift
//  NR Status
//

import Foundation

/// Connection settings for NerdGraph, backed by the same `UserDefaults` keys
/// that `PreferencesView` writes through `@AppStorage`.
struct NerdgraphConfig: Equatable {
    static let defaultHost = "api.newrelic.com"
    static let defaultApiKey = "NRAK-"

    var host: String
    var apiKey: String
    // comma separated, exactly as entered in preferences
    var accountIds: String

    static var current: NerdgraphConfig {
        let defaults = UserDefaults.standard
        return NerdgraphConfig(
            host: defaults.string(forKey: "host") ?? defaultHost,
            apiKey: defaults.string(forKey: "apiKey") ?? defaultApiKey,
            accountIds: defaults.string(forKey: "accountIds") ?? ""
        )
    }

    var url: URL {
        URL(string: "https://\(host)/graphql") ?? URL(string: "https://\(Self.defaultHost)/graphql")!
    }

    /// Parsed account IDs; anything that isn't an integer is dropped so the
    /// values are safe to interpolate into NRQL.
    var accountIdList: [Int] {
        accountIds.split(separator: ",").compactMap { Int($0.trimmingCharacters(in: .whitespaces)) }
    }
}
