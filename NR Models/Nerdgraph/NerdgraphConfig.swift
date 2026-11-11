//
//  NerdgraphConfig.swift
//  NR Status
//

import Foundation

/// Connection settings for NerdGraph. The host and API key live together in one
/// keychain credential (shared with widgets through an access group); account IDs are
/// just a default for queries, so they stay in the shared App Group defaults that
/// `PreferencesView` writes through `@AppStorage`.
struct NerdgraphConfig: Equatable {
    static let defaultHost = "api.newrelic.com"
    static let defaultApiKey = "NRAK-"

    static let appGroup = "EHM929N34N.net.baurhome.NR-Status"

    static let credentialStore: CredentialStore = KeychainStore.shared

    /// Shared with the widget extension.
    static let sharedDefaults = UserDefaults(suiteName: appGroup) ?? .standard

    var host: String
    var apiKey: String
    // comma separated, exactly as entered in preferences
    var accountIds: String

    static var current: NerdgraphConfig {
        let credential = credentialStore.load()
        return NerdgraphConfig(
            host: credential?.host ?? defaultHost,
            apiKey: credential?.apiKey ?? defaultApiKey,
            accountIds: sharedDefaults.string(forKey: "accountIds") ?? ""
        )
    }

    static func saveCredentials(host: String, apiKey: String) {
        let trimmedHost = host.trimmingCharacters(in: .whitespaces)
        credentialStore.save(Credential(
            host: trimmedHost.isEmpty ? defaultHost : trimmedHost,
            apiKey: apiKey
        ))
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
