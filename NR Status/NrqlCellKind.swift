//
//  NrqlCellKind.swift
//  NR Status
//

import Foundation

/// What a cell holds. Text outside a code fence is Markdown; queries and scripts
/// are stored in ```nrql and ```lua fences. A leading ```config cell holds defaults.
/// The editor never shows the fence lines.
enum NrqlCellKind: String, CaseIterable, Identifiable {
    case markdown, nrql, lua, config

    var id: String { rawValue }

    var title: String {
        switch self {
        case .markdown: "Markdown"
        case .nrql: "Query"
        case .lua: "Script"
        case .config: "Document Config"
        }
    }

    /// What a newly added cell is stored as.
    var template: String {
        switch self {
        case .markdown: ""
        case .nrql: "```nrql\nFROM \n```"
        case .lua: "```lua\n\n```"
        case .config: "```config\n\n```"
        }
    }

    private var fenceTag: String? {
        switch self {
        case .markdown: nil
        case .nrql: "nrql"
        case .lua: "lua"
        case .config: "config"
        }
    }

    /// The kind of cell a stored block is, from its first non-blank line.
    static func detect(in stored: String) -> NrqlCellKind {
        guard let first = stored.components(separatedBy: "\n").first(where: { !$0.trimmingCharacters(in: .whitespaces).isEmpty })
        else { return .markdown }
        return fenced(by: first) ?? .markdown
    }

    /// The code kind whose opening fence this line is, if any.
    static func fenced(by line: String) -> NrqlCellKind? {
        let trimmed = line.trimmingCharacters(in: .whitespaces).lowercased()
        if trimmed == "```config" { return .config }
        return [NrqlCellKind.nrql, .lua].first { trimmed.hasPrefix("```" + ($0.fenceTag ?? "")) }
    }

    static func isFence(_ line: String) -> Bool {
        line.trimmingCharacters(in: .whitespaces).hasPrefix("```")
    }

    static func isClosingFence(_ line: String) -> Bool {
        line.trimmingCharacters(in: .whitespaces) == "```"
    }

    /// The stored text without its fence lines; text without a fence is returned as it is.
    func unwrap(_ stored: String) -> String {
        guard fenceTag != nil else { return stored }
        var lines = stored.components(separatedBy: "\n")
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
        guard let tag = fenceTag else { return shown }
        return "```\(tag)\n\(shown)\n```"
    }
}
