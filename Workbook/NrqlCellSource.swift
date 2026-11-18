import Foundation

/// A cell's configuration travels with its content when it is moved, copied, or saved.
struct NrqlCellSource {
    var configuration: String?
    var code: String

    init(configuration: String? = nil, code: String) {
        self.configuration = configuration
        self.code = code
    }

    init(stored: String) {
        let lines = stored.components(separatedBy: "\n")
        guard let open = lines.firstIndex(where: { !$0.trimmingCharacters(in: .whitespaces).isEmpty }),
              lines[open].trimmingCharacters(in: .whitespaces).lowercased() == "```cell_config",
              let close = lines.indices.first(where: { $0 > open && NrqlCellKind.isClosingFence(lines[$0]) })
        else {
            self.init(code: stored)
            return
        }
        self.init(
            configuration: lines[(open + 1)..<close].joined(separator: "\n"),
            code: lines[(close + 1)...].joined(separator: "\n").trimmingCharacters(in: .newlines)
        )
    }

    var storedText: String {
        guard let configuration else { return code }
        return "```cell_config\n\(configuration)\n```\n\(code)"
    }

    func nrqlTimeout() throws -> Int? {
        let values: [String]
        do {
            values = try ConfigurationYAML(configuration ?? "").values("timeout")
        } catch {
            throw NrqlConnection.ConfigurationError(message: error.localizedDescription)
        }
        guard !values.isEmpty else { return nil }
        guard values.count == 1, let seconds = Int(values[0]), seconds > 0 else {
            throw NrqlConnection.ConfigurationError(message: "timeout must be a positive whole number of seconds, specified once.")
        }
        return seconds
    }

    static func value(_ key: String, in text: String) -> String {
        (try? ConfigurationYAML(text).value(key)) ?? ""
    }

    static func values(_ key: String, in text: String) -> [String] {
        (try? ConfigurationYAML(text).values(key)) ?? []
    }

    static func resultName(in text: String) throws -> String? {
        guard let raw = try ConfigurationYAML(text).scalarValue("var") else { return nil }
        let name = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if name.isEmpty { return nil }
        guard !name.contains("="), !name.contains(where: \.isNewline) else {
            throw NrqlConnection.ConfigurationError(
                message: "'var' is a single result name. Put extraction expressions in 'bindings'."
            )
        }
        return name
    }

    /// Preserve unknown keys and comments when a form edits a known setting.
    static func updating(_ key: String, values: [String], in text: String, includeEmptyValues: Bool = false) -> String {
        (try? ConfigurationYAML(text).updating(key, values: values, includeEmptyValues: includeEmptyValues)) ?? text
    }
}
