import Foundation
import Yams

/// Shared by the app, model framework, and widget so configuration has one interpretation.
struct ConfigurationYAML {
    struct ConfigurationError: LocalizedError {
        let message: String
        var errorDescription: String? { message }
    }

    let fields: [(key: String, value: Node)]
    private let source: String
    private let preservesSource: Bool
    private let keyLines: [Int]

    init(_ text: String) throws {
        source = text
        let root: Node?
        do {
            root = try Yams.compose(yaml: text)
        } catch {
            throw ConfigurationError(message: "Invalid YAML configuration: \(error)")
        }
        if root == nil {
            fields = []
            keyLines = []
        } else if let mapping = root?.mapping {
            keyLines = mapping.map { ($0.key.mark?.line ?? 1) - 1 }
            fields = try mapping.map { pair in
                guard let key = pair.key.scalar?.string else {
                    throw ConfigurationError(message: "Configuration keys must be strings.")
                }
                return (Self.canonicalKey(key), pair.value)
            }
        } else {
            throw ConfigurationError(message: "Configuration must be a YAML mapping.")
        }
        preservesSource = root?.mapping?.style != .flow
        var seen = Set<String>()
        for field in fields where !seen.insert(field.key).inserted {
            throw ConfigurationError(message: "Duplicate configuration field '\(field.key)'.")
        }
    }

    static func canonicalKey(_ key: String) -> String {
        let key = key.trimmingCharacters(in: .whitespaces).lowercased()
        return key == "api_key" ? "api-key" : key
    }

    func values(_ key: String) throws -> [String] {
        try fields.filter { $0.key == key }.flatMap { field in
            let nodes = field.value.sequence.map(Array.init) ?? [field.value]
            return try nodes.map { node in
                guard let scalar = node.scalar else {
                    throw ConfigurationError(message: "'\(key)' must be a scalar or a list of scalars.")
                }
                return node.null == nil ? scalar.string : ""
            }
        }
    }

    func value(_ key: String) throws -> String {
        let values = try values(key)
        return key == "accounts" || key == "attributes" ? values.joined(separator: ", ") : values.first ?? ""
    }

    func scalarValue(_ key: String) throws -> String? {
        guard let value = fields.first(where: { $0.key == key })?.value else { return nil }
        guard let scalar = value.scalar else {
            throw ConfigurationError(message: "'\(key)' must be a single value, not a list or mapping.")
        }
        return value.null == nil ? scalar.string : nil
    }

    func mappings(_ key: String) throws -> [[String: String]] {
        guard let value = fields.first(where: { $0.key == key })?.value else { return [] }
        guard let sequence = value.sequence else {
            throw ConfigurationError(message: "'\(key)' must be an array of mappings.")
        }
        return try sequence.map { node in
            guard let mapping = node.mapping else {
                throw ConfigurationError(message: "Each '\(key)' entry must be a mapping.")
            }
            return try Dictionary(uniqueKeysWithValues: mapping.map { field in
                guard let name = field.key.scalar?.string, let value = field.value.scalar?.string else {
                    throw ConfigurationError(message: "'\(key)' entry fields must be scalar values.")
                }
                return (name, field.value.null == nil ? value : "")
            })
        }
    }

    var displayFields: [(key: String, value: String)] {
        fields.map { field in
            let value = field.value.scalar.map { field.value.null == nil ? $0.string : "" }
                ?? (try? Self.serialize(field.value)) ?? ""
            return (field.key, value)
        }
    }

    func updating(_ key: String, values: [String], includeEmptyValues: Bool = false) throws -> String {
        let values = values.filter { includeEmptyValues || !$0.isEmpty }
        func node(_ value: String) -> Node {
            let numeric = ["accounts", "height", "timeout"].contains(key) && Int(value) != nil
            return Node(value, Tag(numeric ? .int : .str))
        }
        let replacement: Node?
        if values.isEmpty {
            replacement = nil
        } else if values.count > 1 {
            replacement = Node(values.map(node))
        } else {
            replacement = node(values[0])
        }
        return try updating(key, replacement: replacement)
    }

    func updating(_ key: String, mappings: [[(String, String)]]) throws -> String {
        let nodes = mappings.map { fields in
            Node(fields.map { (Node($0.0), Node($0.1, Tag(.str))) })
        }
        return try updating(key, replacement: nodes.isEmpty ? nil : Node(nodes))
    }

    private func updating(_ key: String, replacement: Node?) throws -> String {
        var pairs = fields.map { (Node($0.key), $0.value) }
        let insertion = pairs.firstIndex { $0.0.scalar?.string == key } ?? pairs.count
        pairs.removeAll { $0.0.scalar?.string == key }
        if let replacement { pairs.insert((Node(key), replacement), at: min(insertion, pairs.count)) }

        guard preservesSource else {
            return pairs.isEmpty ? "" : try Self.serialize(Node(pairs))
        }

        var lines = source.components(separatedBy: "\n")
        // Replace whole YAML values (including sequences/block scalars), not just their first line.
        var ranges: [Range<Int>] = []
        for (index, field) in fields.enumerated() where field.key == key {
            let lower = keyLines[index]
            var upper = index + 1 < fields.count ? keyLines[index + 1] : lines.count
            while upper > lower + 1 {
                let line = lines[upper - 1]
                if line.isEmpty || line.hasPrefix("#") { upper -= 1 } else { break }
            }
            ranges.append(lower..<upper)
        }
        let rendered = try replacement.map { try Self.serialize(Node([(Node(key), $0)])) }
        if let first = ranges.first {
            for range in ranges.reversed() { lines.removeSubrange(range) }
            if let rendered { lines.insert(contentsOf: rendered.components(separatedBy: "\n"), at: first.lowerBound) }
        } else if let rendered {
            while lines.last?.isEmpty == true { lines.removeLast() }
            lines.append(contentsOf: rendered.components(separatedBy: "\n"))
        }
        return lines.joined(separator: "\n").trimmingCharacters(in: .newlines)
    }

    private static func serialize(_ node: Node) throws -> String {
        try Yams.serialize(node: node, width: -1).trimmingCharacters(in: .newlines)
    }
}
