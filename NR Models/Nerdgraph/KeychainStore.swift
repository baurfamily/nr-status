//
//  KeychainStore.swift
//  NR Status
//

import Foundation
import Security
import os

/// Somewhere to keep credentials. `KeychainStore` is the real one; tests use an in-memory fake.
protocol SecretStore {
    func string(for key: String) -> String?
    func set(_ value: String, for key: String)
    func remove(_ key: String)
}

/// Generic-password items in the data protection keychain, shared between the app
/// and the widget extension through a keychain access group.
struct KeychainStore: SecretStore {
    static let shared = KeychainStore(
        service: "net.baurhome.NR-Status",
        accessGroup: NerdgraphConfig.appGroup
    )

    private static let logger = Logger(subsystem: "com.baurfamily.nrstatus", category: "Keychain")

    let service: String
    let accessGroup: String?

    private func query(for key: String) -> [String: Any] {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecUseDataProtectionKeychain as String: true,
        ]
        if let accessGroup {
            query[kSecAttrAccessGroup as String] = accessGroup
        }
        return query
    }

    func string(for key: String) -> String? {
        var query = query(for: key)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else {
            if status != errSecItemNotFound {
                Self.logger.error("Keychain read failed for \(key, privacy: .public): \(status)")
            }
            return nil
        }
        return String(data: data, encoding: .utf8)
    }

    func set(_ value: String, for key: String) {
        let data = Data(value.utf8)
        let status = SecItemUpdate(
            query(for: key) as CFDictionary,
            [kSecValueData as String: data] as CFDictionary
        )
        if status == errSecItemNotFound {
            var item = query(for: key)
            item[kSecValueData as String] = data
            // widgets read this while the Mac is locked or just after login
            item[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
            let addStatus = SecItemAdd(item as CFDictionary, nil)
            if addStatus != errSecSuccess {
                Self.logger.error("Keychain add failed for \(key, privacy: .public): \(addStatus)")
            }
        } else if status != errSecSuccess {
            Self.logger.error("Keychain update failed for \(key, privacy: .public): \(status)")
        }
    }

    func remove(_ key: String) {
        let status = SecItemDelete(query(for: key) as CFDictionary)
        if status != errSecSuccess && status != errSecItemNotFound {
            Self.logger.error("Keychain delete failed for \(key, privacy: .public): \(status)")
        }
    }
}
