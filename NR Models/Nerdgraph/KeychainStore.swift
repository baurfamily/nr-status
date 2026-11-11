//
//  KeychainStore.swift
//  NR Status
//

import Foundation
import Security
import os

struct Credential: Equatable {
    var host: String
    var apiKey: String
}

/// Somewhere to keep the one NerdGraph credential. `KeychainStore` is the real one;
/// tests use an in-memory fake.
protocol CredentialStore {
    func load() -> Credential?
    func save(_ credential: Credential)
    func remove()
}

/// A single internet-password item: the server is the host and the secret is the API key.
/// It lives in the data protection keychain and is shared between the app and the
/// widget extension through a keychain access group.
struct KeychainStore: CredentialStore {
    static let shared = KeychainStore(
        label: "NR Status API credential",
        accessGroup: NerdgraphConfig.appGroup
    )

    private static let logger = Logger(subsystem: "com.baurfamily.nrstatus", category: "Keychain")
    private static let account = "api-key"

    let label: String
    let accessGroup: String?

    /// Matches our credential whatever its host is.
    private var baseQuery: [String: Any] {
        var query: [String: Any] = [
            kSecClass as String: kSecClassInternetPassword,
            kSecAttrLabel as String: label,
            kSecUseDataProtectionKeychain as String: true,
        ]
        if let accessGroup {
            query[kSecAttrAccessGroup as String] = accessGroup
        }
        return query
    }

    private func query(forHost host: String) -> [String: Any] {
        var query = baseQuery
        query[kSecAttrServer as String] = host
        query[kSecAttrAccount as String] = Self.account
        query[kSecAttrProtocol as String] = kSecAttrProtocolHTTPS
        return query
    }

    func load() -> Credential? {
        var query = baseQuery
        query[kSecReturnAttributes as String] = true
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess,
              let item = result as? [String: Any],
              let host = item[kSecAttrServer as String] as? String,
              let data = item[kSecValueData as String] as? Data,
              let apiKey = String(data: data, encoding: .utf8)
        else {
            if status != errSecItemNotFound && status != errSecSuccess {
                Self.logger.error("Keychain read failed: \(status)")
            }
            return nil
        }
        return Credential(host: host, apiKey: apiKey)
    }

    func save(_ credential: Credential) {
        let data = Data(credential.apiKey.utf8)

        // Add or update the new item first, so a failure never leaves us without a credential.
        var item = query(forHost: credential.host)
        item[kSecValueData as String] = data
        // widgets read this while the Mac is locked or just after login
        item[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        var status = SecItemAdd(item as CFDictionary, nil)
        if status == errSecDuplicateItem {
            status = SecItemUpdate(
                query(forHost: credential.host) as CFDictionary,
                [kSecValueData as String: data] as CFDictionary
            )
        }
        guard status == errSecSuccess else {
            Self.logger.error("Keychain save failed: \(status)")
            return
        }

        removeItems(exceptHost: credential.host)
    }

    func remove() {
        removeItems(exceptHost: nil)
    }

    /// Drops credentials for other hosts, so there is only ever one.
    private func removeItems(exceptHost host: String?) {
        var query = baseQuery
        query[kSecReturnAttributes as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitAll

        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let items = result as? [[String: Any]] else { return }

        for item in items {
            guard let server = item[kSecAttrServer as String] as? String, server != host else { continue }
            let deleteStatus = SecItemDelete(self.query(forHost: server) as CFDictionary)
            if deleteStatus != errSecSuccess && deleteStatus != errSecItemNotFound {
                Self.logger.error("Keychain delete failed: \(deleteStatus)")
            }
        }
    }
}
