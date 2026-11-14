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

/// Storage for one credential. Named profiles have a stable identity separate from their label.
protocol CredentialStore {
    func load() -> Credential?
    func save(_ credential: Credential)
    func remove()
}

/// A single internet-password item: the server is the host and the secret is the API key.
/// It lives in the data protection keychain and is shared between the app and the
/// widget extension through a keychain access group.
struct KeychainStore: CredentialStore {
    struct StoreError: LocalizedError {
        let status: OSStatus

        var errorDescription: String? {
            "Keychain operation failed (\(status)): \(SecCopyErrorMessageString(status, nil) as String? ?? "Unknown error")"
        }
    }

    static let shared = KeychainStore(
        label: "NR Status API credential",
        accessGroup: NerdgraphConfig.appGroup
    )

    private static let logger = Logger(subsystem: "com.baurfamily.nrstatus", category: "Keychain")
    let label: String
    let accessGroup: String?
    let account: String
    let identifier: String?
    let legacyLabel: String?

    init(label: String, accessGroup: String?, account: String = "api-key",
         identifier: String? = nil, legacyLabel: String? = nil) {
        self.label = label
        self.accessGroup = accessGroup
        self.account = account
        self.identifier = identifier
        self.legacyLabel = legacyLabel
    }

    /// An internet password's security domain holds the stable profile ID.
    private var baseQuery: [String: Any] {
        var query: [String: Any] = [
            kSecClass as String: kSecClassInternetPassword,
            kSecUseDataProtectionKeychain as String: true,
        ]
        if let identifier {
            query[kSecAttrSecurityDomain as String] = identifier
        } else {
            query[kSecAttrLabel as String] = label
        }
        if let accessGroup {
            query[kSecAttrAccessGroup as String] = accessGroup
        }
        return query
    }

    private var lookupQueries: [[String: Any]] {
        guard let legacyLabel else { return [baseQuery] }
        var legacy = baseQuery
        legacy.removeValue(forKey: kSecAttrSecurityDomain as String)
        legacy[kSecAttrLabel as String] = legacyLabel
        return [baseQuery, legacy]
    }

    func load() -> Credential? {
        do {
            return try loadChecked()
        } catch {
            Self.logger.error("\(error.localizedDescription, privacy: .public)")
            return nil
        }
    }

    func loadChecked() throws -> Credential? {
        for var query in lookupQueries {
            query[kSecReturnAttributes as String] = true
            query[kSecReturnData as String] = true
            query[kSecMatchLimit as String] = kSecMatchLimitOne

            var result: CFTypeRef?
            let status = SecItemCopyMatching(query as CFDictionary, &result)
            if status == errSecItemNotFound { continue }
            guard status == errSecSuccess else { throw StoreError(status: status) }
            guard let item = result as? [String: Any],
                  let host = item[kSecAttrServer as String] as? String,
                  let data = item[kSecValueData as String] as? Data,
                  let apiKey = String(data: data, encoding: .utf8)
            else {
                throw StoreError(status: errSecDecode)
            }
            return Credential(host: host, apiKey: apiKey)
        }
        return nil
    }

    func save(_ credential: Credential) {
        do {
            try saveChecked(credential)
        } catch {
            Self.logger.error("\(error.localizedDescription, privacy: .public)")
        }
    }

    func saveChecked(_ credential: Credential) throws {
        var attributes: [String: Any] = [
            kSecAttrLabel as String: label,
            kSecAttrServer as String: credential.host,
            kSecAttrAccount as String: account,
            kSecAttrProtocol as String: kSecAttrProtocolHTTPS,
            kSecValueData as String: Data(credential.apiKey.utf8),
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock,
        ]
        if let identifier { attributes[kSecAttrSecurityDomain as String] = identifier }
        // Updating the old UUID label in place preserves the credential during migration.
        var status = errSecItemNotFound
        for query in lookupQueries {
            status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
            if status != errSecItemNotFound { break }
        }
        if status == errSecItemNotFound {
            let item = baseQuery.merging(attributes) { _, value in value }
            status = SecItemAdd(item as CFDictionary, nil)
        }
        guard status == errSecSuccess else {
            throw StoreError(status: status)
        }
    }

    func remove() {
        do {
            try removeChecked()
        } catch {
            Self.logger.error("\(error.localizedDescription, privacy: .public)")
        }
    }

    func removeChecked() throws {
        for query in lookupQueries {
            let status = SecItemDelete(query as CFDictionary)
            if status != errSecSuccess && status != errSecItemNotFound {
                throw StoreError(status: status)
            }
        }
    }
}
