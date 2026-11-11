//
//  CredentialMigrationTests.swift
//  NR StatusTests
//

import Testing
import Foundation
@testable import NR_Status

private final class InMemorySecrets: SecretStore {
    var values: [String: String] = [:]
    var writesFail = false

    func string(for key: String) -> String? { values[key] }
    func set(_ value: String, for key: String) {
        if !writesFail { values[key] = value }
    }
    func remove(_ key: String) { values[key] = nil }
}

struct CredentialMigrationTests {
    private func makeDefaults() -> UserDefaults {
        let name = "test-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        return defaults
    }

    @Test func movesLegacyCredentialsIntoSecretsAndClearsDefaults() {
        let defaults = makeDefaults()
        defaults.set("eu01.api.newrelic.com", forKey: "host")
        defaults.set("NRAK-SECRET", forKey: "apiKey")
        defaults.set("123", forKey: "accountIds")
        let secrets = InMemorySecrets()

        NerdgraphConfig.migrateCredentialsToKeychain(from: [defaults], into: secrets)

        #expect(secrets.values["host"] == "eu01.api.newrelic.com")
        #expect(secrets.values["apiKey"] == "NRAK-SECRET")
        #expect(defaults.string(forKey: "host") == nil)
        #expect(defaults.string(forKey: "apiKey") == nil)
        #expect(defaults.string(forKey: "accountIds") == "123")
    }

    @Test func keepsLegacyValuesWhenSecretsCannotBeWritten() {
        let defaults = makeDefaults()
        defaults.set("NRAK-SECRET", forKey: "apiKey")
        let secrets = InMemorySecrets()
        secrets.writesFail = true

        NerdgraphConfig.migrateCredentialsToKeychain(from: [defaults], into: secrets)

        #expect(defaults.string(forKey: "apiKey") == "NRAK-SECRET")
    }

    @Test func existingSecretsWinOverLegacyValues() {
        let defaults = makeDefaults()
        defaults.set("NRAK-OLD", forKey: "apiKey")
        let secrets = InMemorySecrets()
        secrets.values["apiKey"] = "NRAK-NEW"

        NerdgraphConfig.migrateCredentialsToKeychain(from: [defaults], into: secrets)

        #expect(secrets.values["apiKey"] == "NRAK-NEW")
        #expect(defaults.string(forKey: "apiKey") == nil)
    }
}
