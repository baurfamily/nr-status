//
//  KeychainStoreTests.swift
//  NR StatusTests
//

import Testing
import Foundation
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
}
