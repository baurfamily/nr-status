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
    private static let legacyCredentialKeys = ["host", "apiKey"]

    /// Replaced in tests.
    static var credentialStore: CredentialStore = KeychainStore.shared

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
    /// keychain. The old copies are only deleted once the keychain has a credential.
    static func migrateCredentialsToKeychain(
        from defaultsList: [UserDefaults] = [sharedDefaults, .standard],
        into store: CredentialStore = credentialStore
    ) {
        func legacyValue(_ key: String) -> String? {
            defaultsList.lazy.compactMap { $0.string(forKey: key) }.first
        }

        if store.load() == nil, let apiKey = legacyValue("apiKey") {
            store.save(Credential(host: legacyValue("host") ?? defaultHost, apiKey: apiKey))
        }
        guard store.load() != nil else { return }
        for key in legacyCredentialKeys {
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
        let credential = credentialStore.load()
        return NerdgraphConfig(
            host: credential?.host ?? defaultHost,
            apiKey: credential?.apiKey ?? defaultApiKey,
            accountIds: sharedDefaults.string(forKey: "accountIds") ?? ""
        )
    }

    static func saveCredentials(host: String, apiKey: String) {
        _ = migrated
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
