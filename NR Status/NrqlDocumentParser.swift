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

    /// Splits text into cells: each ```nrql, ```lua, ```graphql or ```config fence is a cell, and
    /// whatever lies between them is one Markdown cell (blank lines included).
    /// An adjacent ```variables fence belongs to the preceding GraphQL cell.
    /// Other fences, such as ```swift, are Markdown content, so a ```nrql inside one stays text.
    static func blocks(_ text: String) -> [String] {
        var blocks: [String] = []
        var current: [String] = []
        var inCode = false
        var inProseFence = false
        var attachingVariables = false

        func flush() {
            let block = current.joined(separator: "\n").trimmingCharacters(in: .newlines)
            if !block.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                if attachingVariables, !blocks.isEmpty {
                    blocks[blocks.count - 1] += "\n" + block
                } else {
                    blocks.append(block)
                }
            }
            current.removeAll()
            attachingVariables = false
        }

        for line in text.components(separatedBy: "\n") {
            if inCode {
                current.append(line)
                if NrqlCellKind.isClosingFence(line) {
                    flush()
                    inCode = false
                }
            } else if inProseFence {
                current.append(line)
                if NrqlCellKind.isClosingFence(line) { inProseFence = false }
            } else if NrqlCellKind.fenced(by: line) != nil {
                flush()
                current.append(line)
                inCode = true
            } else if line.trimmingCharacters(in: .whitespaces).lowercased() == "```variables",
                      current.allSatisfy({ $0.trimmingCharacters(in: .whitespaces).isEmpty }),
                      let previous = blocks.last, NrqlCellKind.detect(in: previous) == .nerdgraph,
                      !NerdgraphCellSource(stored: previous).hasVariables {
                current.removeAll()
                current.append(line)
                attachingVariables = true
                inCode = true
            } else {
                if NrqlCellKind.isFence(line) { inProseFence = true }
                current.append(line)
            }
        }
        flush()
        return blocks
    }

    /// Inverse of `blocks(_:)`.
    static func join(_ blocks: [String]) -> String {
        blocks.filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .joined(separator: "\n\n") + "\n"
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
