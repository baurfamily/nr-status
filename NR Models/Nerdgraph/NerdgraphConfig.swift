//
//  NerdgraphConfig.swift
//  NR Status
//

import Foundation
import os

/// A resolved connection. Documents store profile names, never this value.
struct NerdgraphConfig: Equatable, Hashable, Sendable {
    static let defaultHost = "api.newrelic.com"
    static let defaultApiKey = "NRAK-"

    static let appGroup = "EHM929N34N.net.baurhome.NR-Status"

    /// Shared with the widget extension.
    static let sharedDefaults = UserDefaults(suiteName: appGroup) ?? .standard

    var host: String
    var apiKey: String
    // comma-separated IDs for the NerdGraph request
    var accountIds: String

    static var current: NerdgraphConfig {
        do {
            if let config = try NerdgraphProfiles.shared.defaultConfig() { return config }
        } catch {
            Logger(subsystem: "com.baurfamily.nrstatus", category: "Configuration")
                .error("Could not load API key settings: \(error.localizedDescription, privacy: .public)")
        }
        return NerdgraphConfig(
            host: defaultHost,
            apiKey: defaultApiKey,
            accountIds: ""
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
