//
//  NerdgraphConfig.swift
//  NR Status
//

import Foundation

/// Connection settings for NerdGraph, backed by the shared App Group defaults
/// that `PreferencesView` writes through `@AppStorage`, so widgets see them too.
struct NerdgraphConfig: Equatable {
    static let defaultHost = "api.newrelic.com"
    static let defaultApiKey = "NRAK-"

    static let appGroup = "EHM929N34N.net.baurhome.NR-Status"
    private static let keys = ["host", "apiKey", "accountIds"]

    /// Shared with the widget extension. Values saved before the App Group
    /// existed are copied over once.
    static let sharedDefaults: UserDefaults = {
        guard let shared = UserDefaults(suiteName: appGroup) else { return .standard }
        for key in keys where shared.object(forKey: key) == nil {
            if let old = UserDefaults.standard.object(forKey: key) {
                shared.set(old, forKey: key)
            }
        }
        return shared
    }()

    var host: String
    var apiKey: String
    // comma separated, exactly as entered in preferences
    var accountIds: String

    static var current: NerdgraphConfig {
        let defaults = sharedDefaults
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
