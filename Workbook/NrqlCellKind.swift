//
//  NrqlCellKind.swift
//  NR Status
//

import Foundation

/// What a cell holds. Text outside a code fence is Markdown; queries and scripts
/// are stored in ```nrql, ```lua, and ```graphql fences. GraphQL can have an adjacent
/// ```variables fence. Leading YAML frontmatter holds defaults.
/// The editor never shows the fence lines.
enum NrqlCellKind: String, CaseIterable, Identifiable {
    case markdown, nrql, lua, nerdgraph, config

    var id: String { rawValue }

    var title: String {
        switch self {
        case .markdown: "Markdown"
        case .nrql: "Query"
        case .lua: "Script"
        case .nerdgraph: "Nerdgraph"
        case .config: "Document Config"
        }
    }

    /// What a newly added cell is stored as.
    var template: String {
        switch self {
        case .markdown: ""
        case .nrql: "```nrql\nFROM \n```"
        case .lua: "```lua\n\n```"
        case .nerdgraph: "```graphql\n{\n  actor {\n    user {\n      name\n    }\n  }\n}\n```\n```variables\n{}\n```"
        case .config: "---\nauthor:\ndescription:\n---"
        }
    }

    private var fenceTag: String? {
        switch self {
        case .markdown: nil
        case .nrql: "nrql"
        case .lua: "lua"
        case .nerdgraph: "graphql"
        case .config: nil
        }
    }

    /// The kind of cell a stored block is, from its first non-blank line.
    static func detect(in stored: String) -> NrqlCellKind {
        let code = NrqlCellSource(stored: stored).code
        guard let first = code.components(separatedBy: "\n").first(where: { !$0.trimmingCharacters(in: .whitespaces).isEmpty })
        else { return .markdown }
        return isFrontmatterDelimiter(first) ? .config : fenced(by: first) ?? .markdown
    }

    /// The code kind whose opening fence this line is, if any.
    static func fenced(by line: String) -> NrqlCellKind? {
        let trimmed = line.trimmingCharacters(in: .whitespaces).lowercased()
        if trimmed == "```graphql" || trimmed == "```nerdgraph" { return .nerdgraph }
        return [NrqlCellKind.nrql, .lua].first { trimmed.hasPrefix("```" + ($0.fenceTag ?? "")) }
    }

    static func isFence(_ line: String) -> Bool {
        line.trimmingCharacters(in: .whitespaces).hasPrefix("```")
    }

    static func isClosingFence(_ line: String) -> Bool {
        line.trimmingCharacters(in: .whitespaces) == "```"
    }

    static func isFrontmatterDelimiter(_ line: String) -> Bool {
        line.hasPrefix("---") && line.trimmingCharacters(in: .whitespaces) == "---"
    }

    static func isFrontmatterEnd(_ line: String) -> Bool {
        isFrontmatterDelimiter(line) || line.hasPrefix("...") && line.trimmingCharacters(in: .whitespaces) == "..."
    }

    static func isClosedConfiguration(_ text: String) -> Bool {
        let lines = text.components(separatedBy: "\n")
        guard let first = lines.firstIndex(where: { !$0.trimmingCharacters(in: .whitespaces).isEmpty }),
              let last = lines.indices.last(where: { !lines[$0].trimmingCharacters(in: .whitespaces).isEmpty }),
              last > first else { return false }
        return isFrontmatterDelimiter(lines[first]) && isFrontmatterEnd(lines[last])
    }

    /// The stored text without its fence lines; text without a fence is returned as it is.
    func unwrap(_ stored: String) -> String {
        if self == .nerdgraph { return NerdgraphCellSource(stored: stored).editorText }
        var lines = NrqlCellSource(stored: stored).code.components(separatedBy: "\n")
        if self == .config,
           let first = lines.firstIndex(where: { !$0.trimmingCharacters(in: .whitespaces).isEmpty }),
           Self.isFrontmatterDelimiter(lines[first]) {
            if let close = lines.indices.first(where: { $0 > first && Self.isFrontmatterEnd(lines[$0]) }) {
                lines.removeSubrange(close...)
            }
            lines.removeSubrange(...first)
            return lines.joined(separator: "\n")
        }
        guard fenceTag != nil else { return NrqlCellSource(stored: stored).code }
        guard let open = lines.firstIndex(where: { !$0.trimmingCharacters(in: .whitespaces).isEmpty }),
              Self.fenced(by: lines[open]) == self
        else { return stored }
        if let close = lines.indices.last(where: { $0 > open && Self.isClosingFence(lines[$0]) }) {
            lines.remove(at: close)
        }
        lines.remove(at: open)
        return lines.joined(separator: "\n")
    }

    /// The editor text put back inside a fence.
    func wrap(_ shown: String) -> String {
        if self == .config { return "---\n\(shown)\n---" }
        if self == .nerdgraph { return NerdgraphCellSource(editorText: shown).storedText }
        guard let tag = fenceTag else { return shown }
        return "```\(tag)\n\(shown)\n```"
    }
}
