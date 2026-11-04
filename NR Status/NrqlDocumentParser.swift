//
//  NrqlDocumentParser.swift
//  NR Status
//

import Foundation

/// Splits editor text into queries. Queries are separated by blank lines and
/// may start with `//` comment lines (the first one acts as the title).
enum NrqlDocumentParser {
    struct ParsedQuery: Equatable {
        // covers the query lines (not the leading comments), as UTF-16 offsets
        // so it can be used directly as an NSRange in the editor
        var range: NSRange
        // full text of the block, including comments
        var text: String
    }

    static func parse(_ text: String) -> [ParsedQuery] {
        var queries: [ParsedQuery] = []

        var offset = 0
        var queryStart: Int?
        var lines: [String] = []

        func flush(endingAt end: Int) {
            defer {
                queryStart = nil
                lines.removeAll()
            }
            // a block of only comments isn't a query
            guard let start = queryStart else { return }
            queries.append(
                ParsedQuery(range: NSRange(location: start, length: end - start), text: lines.joined(separator: "\n"))
            )
        }

        for substring in text.split(separator: "\n", omittingEmptySubsequences: false) {
            let line = String(substring)

            if line.isEmpty {
                flush(endingAt: offset)
            } else {
                if queryStart == nil && !line.starts(with: "//") {
                    queryStart = offset
                }
                lines.append(line)
            }

            // include the newline we split on
            offset += line.utf16.count + 1
        }

        // the last block usually isn't followed by a blank line; its range
        // runs one past the end so a cursor at the very end still falls inside it
        flush(endingAt: offset)

        return queries
    }
}
