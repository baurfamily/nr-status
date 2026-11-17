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
        let values = Self.values("timeout", in: configuration ?? "")
        guard !values.isEmpty else { return nil }
        guard values.count == 1, let seconds = Int(values[0]), seconds > 0 else {
            throw NrqlConnection.ConfigurationError(message: "timeout must be a positive whole number of seconds, specified once.")
        }
        return seconds
    }

    static func value(_ key: String, in text: String) -> String {
        values(key, in: text).first ?? ""
    }

    static func values(_ key: String, in text: String) -> [String] {
        text.components(separatedBy: "\n").compactMap { line in
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if key == "var", trimmed.hasPrefix("var ") { return String(trimmed.dropFirst(4)) }
            guard let colon = line.firstIndex(of: ":"),
                  canonicalKey(String(line[..<colon])) == key else { return nil }
            return line[line.index(after: colon)...].trimmingCharacters(in: .whitespaces)
        }
    }

    /// Preserve unknown keys and comments when a form edits a known setting.
    static func updating(_ key: String, values: [String], in text: String, includeEmptyValues: Bool = false) -> String {
        var lines = text.components(separatedBy: "\n")
        let insertion = lines.firstIndex { line in
            if key == "var", line.trimmingCharacters(in: .whitespaces).hasPrefix("var ") { return true }
            guard let colon = line.firstIndex(of: ":") else { return false }
            return canonicalKey(String(line[..<colon])) == key
        } ?? lines.count
        lines.removeAll { line in
            if key == "var", line.trimmingCharacters(in: .whitespaces).hasPrefix("var ") { return true }
            guard let colon = line.firstIndex(of: ":") else { return false }
            return canonicalKey(String(line[..<colon])) == key
        }
        lines.insert(contentsOf: values.filter { includeEmptyValues || !$0.isEmpty }.map { "\(key): \($0)" }, at: min(insertion, lines.count))
        return lines.joined(separator: "\n").trimmingCharacters(in: .newlines)
    }

    private static func canonicalKey(_ key: String) -> String {
        let trimmed = key.trimmingCharacters(in: .whitespaces).lowercased()
        return trimmed == "api_key" ? "api-key" : trimmed
    }
}
