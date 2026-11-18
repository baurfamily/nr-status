import Foundation

/// Non-secret routing options shared by document and cell configuration fences.
struct NrqlConnection: Equatable, Sendable {
    var apiKeyName: String?
    var accountIds: [Int]?
    var variables: [LuaRuntime.Variable] = []

    struct Snapshot: Equatable, Sendable {
        let profileID: UUID
        let host: String
        let accountIds: Set<Int>
    }

    struct ConfigurationError: LocalizedError {
        let message: String
        var errorDescription: String? { message }
    }

    static func metadataBody(in text: String, allowUnclosed: Bool = false) -> String {
        NrqlCellSource(stored: text).configuration ?? ""
    }

    static func parseDocumentConfig(_ text: String) throws -> NrqlConnection {
        try parse(text, strict: true)
    }

    func documentConfigText(preserving text: String = "") throws -> String {
        _ = try Self.parseDocumentConfig(text)
        var body = try ConfigurationYAML(text).updating("api-key", values: apiKeyName.map { [$0] } ?? [])
        body = try ConfigurationYAML(body).updating("accounts", values: accountIds?.map(String.init) ?? [])
        _ = try Self.parseDocumentConfig(body)
        return body
    }

    static func parse(_ body: String, strict: Bool = false) throws -> NrqlConnection {
        var connection = NrqlConnection()
        let yaml: ConfigurationYAML
        do {
            yaml = try ConfigurationYAML(body)
        } catch {
            throw ConfigurationError(message: error.localizedDescription)
        }
        if strict {
            guard !yaml.fields.contains(where: { $0.key == "var" }) else {
                throw ConfigurationError(message: "Use 'bindings' with name/expression entries in document configuration, not 'var'.")
            }
            var seen = Set<String>()
            for record in try yaml.mappings("bindings") {
                let variable = try LuaRuntime.Variable.parse(record)
                guard !LuaRuntime.reservedConfigFields.contains(variable.name), seen.insert(variable.name).inserted else {
                    throw ConfigurationError(message: "Duplicate or reserved config variable '\(variable.name)'.")
                }
                connection.variables.append(variable)
            }
        } else {
            _ = try NrqlCellSource.resultName(in: body)
            _ = try yaml.mappings("bindings")
        }
        if yaml.fields.contains(where: { $0.key == "api-key" }) {
            let values = try yaml.values("api-key")
            guard values.count == 1, let value = values.first, !value.isEmpty,
                  !value.uppercased().hasPrefix("NRAK-") else {
                throw ConfigurationError(message: "api-key must be a saved key name, not a secret API key.")
            }
            connection.apiKeyName = value
        }
        if yaml.fields.contains(where: { $0.key == "accounts" }) {
            let ids = try NerdgraphProfiles.parseAccountIds(yaml.value("accounts"))
            guard !ids.isEmpty else { throw NerdgraphProfiles.ProfileError.missingAccounts }
            connection.accountIds = ids
        }
        // Validate the shared scalar/list settings even when a cell does not execute them.
        for key in ["title", "chart", "attributes", "height", "query", "timeout", "widget-id"] {
            _ = try yaml.values(key)
        }
        return connection
    }

    func inheriting(_ defaults: NrqlConnection) -> NrqlConnection {
        NrqlConnection(apiKeyName: apiKeyName ?? defaults.apiKeyName, accountIds: accountIds ?? defaults.accountIds,
                       variables: variables.isEmpty ? defaults.variables : variables)
    }

    func effectiveConfiguration(profiles: NerdgraphProfiles.Settings) throws -> NrqlConnection {
        let profile = profiles.profiles.first {
            if let apiKeyName { return $0.name.caseInsensitiveCompare(apiKeyName) == .orderedSame }
            return $0.id == profiles.defaultProfileID
        }
        guard let profile else {
            guard apiKeyName == nil, profiles.defaultProfileID == nil else {
                throw NerdgraphProfiles.ProfileError.missingProfile
            }
            return NrqlConnection(accountIds: accountIds ?? [], variables: variables)
        }
        return NrqlConnection(apiKeyName: profile.name, accountIds: accountIds ?? profile.preferredAccountIds, variables: variables)
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
        if let name = try? ConfigurationYAML(body).value("api-key"), !name.isEmpty { return name }
        for line in body.components(separatedBy: .newlines) {
            guard let colon = line.firstIndex(of: ":"),
                  ["api-key", "api_key"].contains(line[..<colon].trimmingCharacters(in: .whitespaces).lowercased()) else { continue }
            let value = line[line.index(after: colon)...].trimmingCharacters(in: .whitespaces)
            return value.isEmpty ? nil : value
        }
        return nil
    }
}
