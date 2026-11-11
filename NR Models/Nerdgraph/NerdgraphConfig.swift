//
//  NerdgraphConfig.swift
//  NR Status
//

import Foundation

/// Connection settings for NerdGraph. The host and API key live in the keychain
/// (shared with widgets through an access group); account IDs are just a default
/// for queries, so they stay in the shared App Group defaults that `PreferencesView`
/// writes through `@AppStorage`.
struct NerdgraphConfig: Equatable {
    static let defaultHost = "api.newrelic.com"
    static let defaultApiKey = "NRAK-"

    static let appGroup = "EHM929N34N.net.baurhome.NR-Status"
    private static let credentialKeys = ["host", "apiKey"]

    /// Replaced in tests.
    static var secrets: SecretStore = KeychainStore.shared

    /// Shared with the widget extension. Account IDs saved before the App Group
    /// existed are copied over once.
    static let sharedDefaults: UserDefaults = {
        guard let shared = UserDefaults(suiteName: appGroup) else { return .standard }
        if shared.object(forKey: "accountIds") == nil,
           let old = UserDefaults.standard.object(forKey: "accountIds") {
            shared.set(old, forKey: "accountIds")
        }
        return shared
    }()

    /// Moves a host and key saved in `UserDefaults` by older versions into the
    /// keychain. The old copies are only deleted once the keychain has the value.
    static func migrateCredentialsToKeychain(
        from defaultsList: [UserDefaults] = [sharedDefaults, .standard],
        into secrets: SecretStore = secrets
    ) {
        for key in credentialKeys {
            if secrets.string(for: key) == nil,
               let old = defaultsList.lazy.compactMap({ $0.string(forKey: key) }).first {
                secrets.set(old, for: key)
            }
            guard secrets.string(for: key) != nil else { continue }
            for defaults in defaultsList {
                defaults.removeObject(forKey: key)
            }
        }
    }

    private static let migrated: Void = migrateCredentialsToKeychain()

    var host: String
    var apiKey: String
    // comma separated, exactly as entered in preferences
    var accountIds: String

    static var current: NerdgraphConfig {
        _ = migrated
        return NerdgraphConfig(
            host: secrets.string(for: "host") ?? defaultHost,
            apiKey: secrets.string(for: "apiKey") ?? defaultApiKey,
            accountIds: sharedDefaults.string(forKey: "accountIds") ?? ""
        )
    }

    static func saveCredentials(host: String, apiKey: String) {
        _ = migrated
        secrets.set(host, for: "host")
        secrets.set(apiKey, for: "apiKey")
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
