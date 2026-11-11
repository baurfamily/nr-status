//
//  CredentialMigrationTests.swift
//  NR StatusTests
//

import Testing
import Foundation
@testable import NR_Status

private final class InMemoryCredentialStore: CredentialStore {
    var credential: Credential?
    var writesFail = false

    func load() -> Credential? { credential }
    func save(_ credential: Credential) {
        if !writesFail { self.credential = credential }
    }
    func remove() { credential = nil }
}

struct KeychainStoreTests {
    @Test func keepsASingleCredentialAcrossHostChanges() {
        let store = KeychainStore(label: "NR Status test \(UUID().uuidString)", accessGroup: nil)
        defer { store.remove() }

        store.save(Credential(host: "a.example.com", apiKey: "key-1"))
        #expect(store.load() == Credential(host: "a.example.com", apiKey: "key-1"))

        store.save(Credential(host: "a.example.com", apiKey: "key-2"))
        #expect(store.load() == Credential(host: "a.example.com", apiKey: "key-2"))

        store.save(Credential(host: "b.example.com", apiKey: "key-3"))
        #expect(store.load() == Credential(host: "b.example.com", apiKey: "key-3"))

        store.remove()
        #expect(store.load() == nil)
    }
}

struct CredentialMigrationTests {
    private func makeDefaults() -> UserDefaults {
        let name = "test-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        return defaults
    }

    @Test func movesLegacyCredentialIntoStoreAndClearsDefaults() {
        let defaults = makeDefaults()
        defaults.set("eu01.api.newrelic.com", forKey: "host")
        defaults.set("NRAK-SECRET", forKey: "apiKey")
        defaults.set("123", forKey: "accountIds")
        let store = InMemoryCredentialStore()

        NerdgraphConfig.migrateCredentialsToKeychain(from: [defaults], into: store)

        #expect(store.credential == Credential(host: "eu01.api.newrelic.com", apiKey: "NRAK-SECRET"))
        #expect(defaults.string(forKey: "host") == nil)
        #expect(defaults.string(forKey: "apiKey") == nil)
        #expect(defaults.string(forKey: "accountIds") == "123")
    }

    @Test func legacyKeyWithoutHostUsesDefaultHost() {
        let defaults = makeDefaults()
        defaults.set("NRAK-SECRET", forKey: "apiKey")
        let store = InMemoryCredentialStore()

        NerdgraphConfig.migrateCredentialsToKeychain(from: [defaults], into: store)

        #expect(store.credential == Credential(host: NerdgraphConfig.defaultHost, apiKey: "NRAK-SECRET"))
    }

    @Test func keepsLegacyValuesWhenStoreCannotBeWritten() {
        let defaults = makeDefaults()
        defaults.set("NRAK-SECRET", forKey: "apiKey")
        let store = InMemoryCredentialStore()
        store.writesFail = true

        NerdgraphConfig.migrateCredentialsToKeychain(from: [defaults], into: store)

        #expect(defaults.string(forKey: "apiKey") == "NRAK-SECRET")
    }

    @Test func existingCredentialWinsOverLegacyValues() {
        let defaults = makeDefaults()
        defaults.set("NRAK-OLD", forKey: "apiKey")
        let store = InMemoryCredentialStore()
        store.credential = Credential(host: "api.newrelic.com", apiKey: "NRAK-NEW")

        NerdgraphConfig.migrateCredentialsToKeychain(from: [defaults], into: store)

        #expect(store.credential?.apiKey == "NRAK-NEW")
        #expect(defaults.string(forKey: "apiKey") == nil)
    }
}
