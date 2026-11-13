//
//  NrqlScriptFence.swift
//  NR Status
//

import Foundation

/// A script cell is stored as a ```lua fenced block, so blank lines inside it
/// survive. The editor shows only the Lua (and any format block above it); these
/// convert between that and the stored text.
enum NrqlScriptFence {
    private static let opening = "```lua"
    private static let closing = "```"

    /// The stored text without its fence lines.
    static func unwrap(_ stored: String) -> String {
        var lines = stored.components(separatedBy: "\n")
        guard let open = lines.firstIndex(where: { $0.trimmingCharacters(in: .whitespaces).lowercased().hasPrefix(opening) })
        else { return stored }
        if let close = lines.indices.last(where: { $0 > open && lines[$0].trimmingCharacters(in: .whitespaces) == closing }) {
            lines.remove(at: close)
        }
        lines.remove(at: open)
        return lines.joined(separator: "\n")
    }

    /// The editor text with a fence put around the code, after any leading format block.
    static func wrap(_ shown: String) -> String {
        let lines = shown.components(separatedBy: "\n")
        let header = headerLength(of: lines)
        return (Array(lines[..<header]) + [opening] + Array(lines[header...]) + [closing]).joined(separator: "\n")
    }

    // lines taken by a format block at the top, including blank lines before it
    private static func headerLength(of lines: [String]) -> Int {
        guard let start = lines.firstIndex(where: { !$0.trimmingCharacters(in: .whitespaces).isEmpty }),
              lines[start].trimmingCharacters(in: .whitespaces).hasPrefix("/***")
        else { return 0 }
        let end = lines[start...].firstIndex { $0.contains("***/") }
        return end.map { $0 + 1 } ?? 0
    }
}
