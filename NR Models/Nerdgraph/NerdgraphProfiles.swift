import Foundation

struct NerdgraphProfile: Codable, Equatable, Identifiable, Sendable {
    var id = UUID()
    var name: String
    var host = NerdgraphConfig.defaultHost
    var preferredAccountIds: [Int] = []
}

/// Only profile metadata goes in defaults; each secret has its own Keychain item.
struct NerdgraphProfiles {
    struct Settings: Codable, Equatable {
        var profiles: [NerdgraphProfile] = []
        var defaultProfileID: UUID?
    }

    enum ProfileError: LocalizedError {
        case invalidName, duplicateName, missingProfile, missingKey, missingAccounts, invalidAccounts

        var errorDescription: String? {
            switch self {
            case .invalidName: "Enter a key name without line breaks or an API key value."
            case .duplicateName: "A key with that name already exists."
            case .missingProfile: "The selected API key name was not found. Configure it in Settings."
            case .missingKey: "No API key is stored for this profile. Add it in Settings."
            case .missingAccounts: "Specify at least one account ID in the document, query, or key's preferred accounts."
            case .invalidAccounts: "Account IDs must be positive integers, separated by commas."
            }
        }
    }

    static let shared = NerdgraphProfiles()
    let defaults: UserDefaults
    let legacyStore: KeychainStore
    let labelPrefix: String
    let accessGroup: String?
    private let settingsKey = "nerdgraphProfiles"

    init(defaults: UserDefaults = NerdgraphConfig.sharedDefaults, legacyStore: KeychainStore = .shared,
         labelPrefix: String = "NR Status named API key", accessGroup: String? = NerdgraphConfig.appGroup) {
        self.defaults = defaults
        self.legacyStore = legacyStore
        self.labelPrefix = labelPrefix
        self.accessGroup = accessGroup
    }

    func keychain(for profile: NerdgraphProfile) -> KeychainStore {
        KeychainStore(
            label: "\(labelPrefix) (\(profile.name))", accessGroup: accessGroup, account: profile.name,
            identifier: profile.id.uuidString, legacyLabel: "\(labelPrefix) \(profile.id.uuidString)"
        )
    }

    func load() throws -> Settings {
        if let data = defaults.data(forKey: settingsKey) {
            return try JSONDecoder().decode(Settings.self, from: data)
        }
        guard let legacy = try legacyStore.loadChecked() else { return Settings() }
        let profile = NerdgraphProfile(
            name: "Default", host: legacy.host,
            preferredAccountIds: NerdgraphConfig(
                host: legacy.host, apiKey: "", accountIds: defaults.string(forKey: "accountIds") ?? ""
            ).accountIdList
        )
        try keychain(for: profile).saveChecked(legacy)
        let settings = Settings(profiles: [profile], defaultProfileID: profile.id)
        try persist(settings)
        // Keep the legacy item until the new credential and metadata are safely written.
        try legacyStore.removeChecked()
        return settings
    }

    @discardableResult
    func save(_ profile: NerdgraphProfile, apiKey: String, makeDefault: Bool) throws -> Settings {
        var settings = try load()
        var profile = profile
        let apiKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        profile.name = profile.name.trimmingCharacters(in: .whitespacesAndNewlines)
        profile.host = profile.host.trimmingCharacters(in: .whitespacesAndNewlines)
        if profile.host.isEmpty { profile.host = NerdgraphConfig.defaultHost }
        guard !profile.name.isEmpty, !profile.name.contains(where: \.isNewline),
              !profile.name.uppercased().hasPrefix("NRAK-") else { throw ProfileError.invalidName }
        guard !settings.profiles.contains(where: {
            $0.id != profile.id && $0.name.caseInsensitiveCompare(profile.name) == .orderedSame
        }) else { throw ProfileError.duplicateName }
        guard !apiKey.isEmpty,
              apiKey != NerdgraphConfig.defaultApiKey else { throw ProfileError.missingKey }
        guard profile.preferredAccountIds.allSatisfy({ $0 > 0 && $0 <= Int(Int32.max) }) else {
            throw ProfileError.invalidAccounts
        }
        try keychain(for: profile).saveChecked(Credential(host: profile.host, apiKey: apiKey))
        if let index = settings.profiles.firstIndex(where: { $0.id == profile.id }) {
            settings.profiles[index] = profile
        } else {
            settings.profiles.append(profile)
        }
        if makeDefault || settings.defaultProfileID == nil { settings.defaultProfileID = profile.id }
        try persist(settings)
        return settings
    }

    @discardableResult
    func remove(_ id: UUID) throws -> Settings {
        var settings = try load()
        guard let profile = settings.profiles.first(where: { $0.id == id }) else { throw ProfileError.missingProfile }
        try keychain(for: profile).removeChecked()
        settings.profiles.removeAll { $0.id == id }
        if settings.defaultProfileID == id { settings.defaultProfileID = settings.profiles.first?.id }
        try persist(settings)
        return settings
    }

    func resolve(name: String? = nil, accountIds: [Int]? = nil) throws -> NerdgraphConfig {
        let settings = try load()
        let profile = settings.profiles.first {
            if let name { return $0.name.caseInsensitiveCompare(name) == .orderedSame }
            return $0.id == settings.defaultProfileID
        }
        guard let profile else { throw ProfileError.missingProfile }
        guard let credential = try keychain(for: profile).loadChecked() else { throw ProfileError.missingKey }
        let ids = accountIds ?? profile.preferredAccountIds
        guard !ids.isEmpty else { throw ProfileError.missingAccounts }
        guard ids.allSatisfy({ $0 > 0 && $0 <= Int(Int32.max) }) else { throw ProfileError.invalidAccounts }
        return NerdgraphConfig(host: credential.host, apiKey: credential.apiKey,
                               accountIds: ids.map(String.init).joined(separator: ","))
    }

    /// Connections used by user/account discovery don't require an account selection.
    func defaultConfig() throws -> NerdgraphConfig? {
        let settings = try load()
        guard let profile = settings.profiles.first(where: { $0.id == settings.defaultProfileID }) else { return nil }
        guard let credential = try keychain(for: profile).loadChecked() else { throw ProfileError.missingKey }
        return NerdgraphConfig(host: credential.host, apiKey: credential.apiKey,
                               accountIds: profile.preferredAccountIds.map(String.init).joined(separator: ","))
    }

    static func parseAccountIds(_ value: String) throws -> [Int] {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return [] }
        var ids: [Int] = []
        var seen = Set<Int>()
        for component in trimmed.split(separator: ",", omittingEmptySubsequences: false) {
            let token = component.trimmingCharacters(in: .whitespaces)
            guard !token.isEmpty, token.allSatisfy(\.isNumber), let id = Int(token),
                  id > 0, id <= Int(Int32.max) else { throw ProfileError.invalidAccounts }
            if seen.insert(id).inserted { ids.append(id) }
        }
        return ids
    }

    private func persist(_ settings: Settings) throws {
        defaults.set(try JSONEncoder().encode(settings), forKey: settingsKey)
    }
}
