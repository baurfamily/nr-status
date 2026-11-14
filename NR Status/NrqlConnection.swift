import Foundation

/// Non-secret routing options shared by document config and query metadata.
struct NrqlConnection: Equatable, Sendable {
    var apiKeyName: String?
    var accountIds: [Int]?

    struct Snapshot: Equatable, Sendable {
        let profileID: UUID
        let host: String
        let accountIds: Set<Int>
    }

    struct ConfigurationError: LocalizedError {
        let message: String
        var errorDescription: String? { message }
    }

    private static let metadata = try! NSRegularExpression(
        pattern: #"/\*\*\*(.*?)\*\*\*/"#, options: [.dotMatchesLineSeparators]
    )

    static func metadataBody(in text: String, allowUnclosed: Bool = false) -> String {
        guard let match = metadata.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              let range = Range(match.range(at: 1), in: text) else {
            if allowUnclosed, let open = text.range(of: "/***") { return String(text[open.upperBound...]) }
            return ""
        }
        return String(text[range])
    }

    static func parseDocumentConfig(_ text: String) throws -> NrqlConnection {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return NrqlConnection() }
        let range = NSRange(trimmed.startIndex..., in: trimmed)
        guard let match = metadata.firstMatch(in: trimmed, range: range), match.range == range else {
            throw ConfigurationError(message: "Document settings must be inside a single /*** ... ***/ block comment.")
        }
        return try parse(metadataBody(in: trimmed), strict: true)
    }

    func documentConfigText(preserving text: String = "") throws -> String {
        _ = try Self.parseDocumentConfig(text)
        var lines = Self.metadataBody(in: text).components(separatedBy: .newlines).filter { line in
            guard let colon = line.firstIndex(of: ":") else { return true }
            let key = line[..<colon].trimmingCharacters(in: .whitespaces).lowercased()
            return key != "api-key" && key != "api_key" && key != "accounts"
        }
        while lines.first?.trimmingCharacters(in: .whitespaces).isEmpty == true { lines.removeFirst() }
        while lines.last?.trimmingCharacters(in: .whitespaces).isEmpty == true { lines.removeLast() }
        if let apiKeyName { lines.append("  api-key: \(apiKeyName)") }
        if let accountIds { lines.append("  accounts: \(accountIds.map(String.init).joined(separator: ", "))") }
        guard !lines.isEmpty else { return "" }
        let body = lines.joined(separator: "\n")
        _ = try Self.parse(body, strict: true)
        return "/***\n\(body)\n***/"
    }

    static func parse(_ body: String, strict: Bool = false) throws -> NrqlConnection {
        var connection = NrqlConnection()
        var seen = Set<String>()
        for line in body.components(separatedBy: .newlines) {
            let line = line.trimmingCharacters(in: .whitespaces)
            if line.isEmpty || line.hasPrefix("//") { continue }
            guard let colon = line.firstIndex(of: ":") else {
                if strict || line == "api-key" || line == "api_key" || line == "accounts" {
                    throw ConfigurationError(message: "Expected 'key: value' in connection configuration.")
                }
                continue
            }
            let rawKey = line[..<colon].trimmingCharacters(in: .whitespaces).lowercased()
            let key = rawKey == "api_key" ? "api-key" : rawKey
            let value = line[line.index(after: colon)...].trimmingCharacters(in: .whitespaces)
            guard ["api-key", "accounts"].contains(key) else { continue }
            guard seen.insert(key).inserted else {
                throw ConfigurationError(message: "Duplicate configuration field '\(key)'.")
            }
            switch key {
            case "api-key":
                guard !value.isEmpty, !value.uppercased().hasPrefix("NRAK-") else {
                    throw ConfigurationError(message: "api-key must be a saved key name, not a secret API key.")
                }
                connection.apiKeyName = value
            case "accounts":
                let ids = try NerdgraphProfiles.parseAccountIds(value)
                guard !ids.isEmpty else { throw NerdgraphProfiles.ProfileError.missingAccounts }
                connection.accountIds = ids
            default: break
            }
        }
        return connection
    }

    func inheriting(_ defaults: NrqlConnection) -> NrqlConnection {
        NrqlConnection(apiKeyName: apiKeyName ?? defaults.apiKeyName, accountIds: accountIds ?? defaults.accountIds)
    }

    func resolve(profiles: NerdgraphProfiles = .shared, requiresAccounts: Bool = true) throws -> NerdgraphConfig {
        try profiles.resolve(name: apiKeyName, accountIds: requiresAccounts ? accountIds : [], requiresAccounts: requiresAccounts)
    }

    /// The non-secret identity of the connection, including inherited preferences.
    func snapshot(profiles: NerdgraphProfiles.Settings, requiresAccounts: Bool = true) throws -> Snapshot {
        guard let profile = profiles.profiles.first(where: {
            if let apiKeyName { return $0.name.caseInsensitiveCompare(apiKeyName) == .orderedSame }
            return $0.id == profiles.defaultProfileID
        }) else { throw NerdgraphProfiles.ProfileError.missingProfile }
        let ids = requiresAccounts ? (accountIds ?? profile.preferredAccountIds) : []
        guard !requiresAccounts || !ids.isEmpty else { throw NerdgraphProfiles.ProfileError.missingAccounts }
        return Snapshot(profileID: profile.id, host: profile.host, accountIds: Set(ids))
    }

    /// Also works while an account list is incomplete, so key-specific suggestions stay available.
    static func keyName(in body: String) -> String? {
        for line in body.components(separatedBy: .newlines) {
            guard let colon = line.firstIndex(of: ":"),
                  ["api-key", "api_key"].contains(line[..<colon].trimmingCharacters(in: .whitespaces).lowercased()) else { continue }
            let value = line[line.index(after: colon)...].trimmingCharacters(in: .whitespaces)
            return value.isEmpty ? nil : value
        }
        return nil
    }
}
