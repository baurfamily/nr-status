//
//  KeychainStoreTests.swift
//  NR StatusTests
//

import Testing
import Foundation
import Security
@testable import NR_Status

struct KeychainStoreTests {
    @Test func keepsASingleCredentialAcrossHostChanges() {
        // unique label, so this never touches the real credential
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

    struct NerdgraphProfilesTests {
        private func storedAttributes(in store: KeychainStore) throws -> [[String: Any]] {
            var query: [String: Any] = [
                kSecClass as String: kSecClassInternetPassword,
                kSecUseDataProtectionKeychain as String: true,
                kSecReturnAttributes as String: true,
                kSecMatchLimit as String: kSecMatchLimitAll,
            ]
            if let identifier = store.identifier {
                query[kSecAttrSecurityDomain as String] = identifier
            } else {
                query[kSecAttrLabel as String] = store.label
            }
            var result: CFTypeRef?
            let status = SecItemCopyMatching(query as CFDictionary, &result)
            if status == errSecItemNotFound { return [] }
            guard status == errSecSuccess else { throw KeychainStore.StoreError(status: status) }
            return try #require(result as? [[String: Any]])
        }

        private func storedAccounts(in store: KeychainStore) throws -> [String] {
            try storedAttributes(in: store).map { try #require($0[kSecAttrAccount as String] as? String) }
        }

        private func withProfiles(_ body: (NerdgraphProfiles) throws -> Void) throws {
            let suite = "NR Status profiles test \(UUID().uuidString)"
            let defaults = try #require(UserDefaults(suiteName: suite))
            let legacy = KeychainStore(label: "\(suite) legacy", accessGroup: nil, account: suite)
            let store = NerdgraphProfiles(defaults: defaults, legacyStore: legacy, labelPrefix: suite, accessGroup: nil)
            defer {
                if let settings = try? store.load() {
                    for profile in settings.profiles { store.keychain(for: profile).remove() }
                }
                legacy.remove()
                defaults.removePersistentDomain(forName: suite)
            }
            try body(store)
        }

        @Test func migratesLegacyCredentialAndAccountsOnlyOnce() throws {
            try withProfiles { store in
                let credential = Credential(host: "\(UUID().uuidString).example.com", apiKey: "legacy-secret")
                try store.legacyStore.saveChecked(credential)
                store.defaults.set("123, 456", forKey: "accountIds")

                let settings = try store.load()
                let profile = try #require(settings.profiles.first)
                #expect(profile.name == "Default")
                #expect(settings.defaultProfileID == profile.id)
                #expect(profile.preferredAccountIds == [123, 456])
                #expect(try store.keychain(for: profile).loadChecked() == credential)
                #expect(try storedAccounts(in: store.keychain(for: profile)) == ["Default"])
                #expect(try store.legacyStore.loadChecked() == nil)
                #expect(try store.load() == settings)
                #expect(try store.resolve().apiKey == "legacy-secret")
                let data = try #require(store.defaults.data(forKey: "nerdgraphProfiles"))
                #expect(!String(decoding: data, as: UTF8.self).contains("legacy-secret"))
            }
        }

        @Test func keepsSameHostKeysIndependentAndResolvesOverrides() throws {
            try withProfiles { store in
                let host = "\(UUID().uuidString).example.com"
                let a = NerdgraphProfile(name: "Production", host: host, preferredAccountIds: [1, 2])
                var b = NerdgraphProfile(name: "Staging", host: host, preferredAccountIds: [3])
                try store.save(a, apiKey: "secret-a", makeDefault: true)
                try store.save(b, apiKey: "secret-b", makeDefault: false)
                #expect(try store.resolve().apiKey == "secret-a")
                #expect(try store.resolve(name: "staging").apiKey == "secret-b")
                #expect(try store.resolve(name: "Staging").accountIdList == [3])
                #expect(try store.resolve(name: "Staging", accountIds: [999, 1000]).accountIdList == [999, 1000])

                let defaults = NrqlConnection(apiKeyName: "Production", accountIds: [8, 9])
                let override = try NrqlConnection.parse("api-key: Staging\naccounts: 42, 43")
                let resolved = try override.inheriting(defaults).resolve(profiles: store)
                #expect(resolved.apiKey == "secret-b")
                #expect(resolved.accountIdList == [42, 43])
                #expect(try NrqlConnection(apiKeyName: "Staging").inheriting(defaults).resolve(profiles: store).accountIdList == [8, 9])

                b.host = "other-\(host)"
                b.name = "Renamed staging"
                try store.save(b, apiKey: "updated-b", makeDefault: true)
                #expect(try store.resolve().host == b.host)
                #expect(try store.resolve(name: "Production").apiKey == "secret-a")
                #expect(throws: NerdgraphProfiles.ProfileError.self) { try store.resolve(name: "Staging") }
                try store.remove(b.id)
                #expect(try store.resolve().apiKey == "secret-a")
                #expect(try store.keychain(for: b).loadChecked() == nil)
            }
        }

        @Test(arguments: [true, false])
        func updatesUUIDLabelsAndRenamesWithoutDuplicatingCredentials(usesUUIDAccount: Bool) throws {
            try withProfiles { store in
                var profile = NerdgraphProfile(
                    name: "Original", host: "\(UUID().uuidString).example.com", preferredAccountIds: [123]
                )
                let settings = NerdgraphProfiles.Settings(profiles: [profile], defaultProfileID: profile.id)
                store.defaults.set(try JSONEncoder().encode(settings), forKey: "nerdgraphProfiles")
                let oldAccount = usesUUIDAccount ? profile.id.uuidString : profile.name
                let oldStore = KeychainStore(
                    label: "\(store.labelPrefix) \(profile.id.uuidString)", accessGroup: nil, account: oldAccount
                )
                try oldStore.saveChecked(Credential(host: profile.host, apiKey: "existing-secret"))

                #expect(try store.resolve().apiKey == "existing-secret")
                #expect(try storedAccounts(in: oldStore) == [oldAccount])
                try store.save(profile, apiKey: "existing-secret", makeDefault: true)
                let namedStore = store.keychain(for: profile)
                #expect(try storedAccounts(in: namedStore) == ["Original"])
                #expect(try storedAccounts(in: oldStore).isEmpty)
                let original = try #require(storedAttributes(in: namedStore).first)
                #expect(original[kSecAttrLabel as String] as? String == "\(store.labelPrefix) (Original)")

                profile.name = "Renamed"
                try store.save(profile, apiKey: "updated-secret", makeDefault: true)
                let renamed = try storedAttributes(in: namedStore)
                #expect(renamed.count == 1)
                #expect(renamed.first?[kSecAttrLabel as String] as? String == "\(store.labelPrefix) (Renamed)")
                #expect(try storedAccounts(in: namedStore) == ["Renamed"])
                #expect(try namedStore.loadChecked()?.apiKey == "updated-secret")
                #expect(try store.resolve(name: "Renamed").apiKey == "updated-secret")
                #expect(throws: NerdgraphProfiles.ProfileError.self) { try store.resolve(name: "Original") }
                try store.remove(profile.id)
                #expect(try storedAttributes(in: namedStore).isEmpty)
                #expect(try storedAccounts(in: oldStore).isEmpty)
            }
        }

        @Test func rejectsUnknownDuplicateAndIncompleteProfiles() throws {
            try withProfiles { store in
                let profile = NerdgraphProfile(name: "Work", host: "\(UUID().uuidString).example.com")
                try store.save(profile, apiKey: "secret", makeDefault: true)
                #expect(throws: NerdgraphProfiles.ProfileError.self) { try store.resolve() }
                #expect(try store.resolve(accountIds: [123]).apiKey == "secret")
                #expect(throws: NerdgraphProfiles.ProfileError.self) { try store.resolve(name: "Missing", accountIds: [123]) }
                #expect(throws: NerdgraphProfiles.ProfileError.self) {
                    try store.save(NerdgraphProfile(name: "work"), apiKey: "other", makeDefault: false)
                }
                #expect(throws: NerdgraphProfiles.ProfileError.self) {
                    try store.save(NerdgraphProfile(name: "NRAK-secret"), apiKey: "other", makeDefault: false)
                }
                #expect(try store.load().profiles.count == 1)
                try store.keychain(for: profile).removeChecked()
                #expect(throws: NerdgraphProfiles.ProfileError.self) { try store.resolve(accountIds: [123]) }
            }
        }
    }
}
