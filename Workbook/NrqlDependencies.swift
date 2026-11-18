//
//  NrqlDependencies.swift
//  NR Status
//

import Foundation

/// Which cells read which other cells' results, found by scanning the `{{ }}`
/// expressions of a query, or the whole of a script, for `results.<name>`.
enum NrqlDependencies {
    private static let resultsIdentifier = try! NSRegularExpression(pattern: #"\bresults\b"#)
    private static let namedReferences = [
        try! NSRegularExpression(pattern: #"results\s*\.\s*([A-Za-z_][A-Za-z0-9_]*)"#),
        try! NSRegularExpression(pattern: #"results\s*\[\s*["']([^"']+)["']\s*\]"#),
    ]

    static func references(in code: String) -> (names: Set<String>, hasUnnamed: Bool) {
        let range = NSRange(code.startIndex..., in: code)
        var names = Set<String>()
        var hasUnnamed = false
        var consumedThrough = code.startIndex
        for identifier in resultsIdentifier.matches(in: code, range: range) {
            guard let identifierRange = Range(identifier.range, in: code),
                  identifierRange.lowerBound >= consumedThrough else { continue }
            let prefix = code[..<identifierRange.lowerBound].trimmingCharacters(in: .whitespacesAndNewlines)
            // A response field named `results` is not the workbook's global results table.
            if prefix.hasSuffix(":") || prefix.hasSuffix(".") && !prefix.hasSuffix("..") { continue }
            let suffix = NSRange(identifierRange.lowerBound..<code.endIndex, in: code)
            if let match = namedReferences.lazy.compactMap({
                $0.firstMatch(in: code, options: .anchored, range: suffix)
            }).first, let nameRange = Range(match.range(at: 1), in: code),
               let matchRange = Range(match.range, in: code) {
                names.insert(String(code[nameRange]))
                consumedThrough = matchRange.upperBound
            } else {
                hasUnnamed = true
            }
        }
        return (names, hasUnnamed)
    }

    static func referencedNames(by cell: NrqlCell) -> Set<String> {
        references(in: cell.query.expressionCode).names
    }

    /// The cells whose results `cell` reads.
    static func dependencies(of cell: NrqlCell, in cells: [NrqlCell]) -> [NrqlCell] {
        var seen = Set<NrqlCell.ID>()
        return referencedNames(by: cell).sorted().compactMap { name in
            guard let source = cells.first(where: {
                $0.id != cell.id && ($0.query.resultNames.contains(name)
                    || $0.query.loadedBindings?.contains(where: { $0.name == name }) == true)
            }), seen.insert(source.id).inserted else { return nil }
            return source
        }
    }

    /// Cells that read the result of a cell placed after them.
    static func cellsReadingBelow(in cells: [NrqlCell]) -> Set<NrqlCell.ID> {
        var result = Set<NrqlCell.ID>()
        for (index, cell) in cells.enumerated() {
            let below = Set(cells[(index + 1)...].map(\.id))
            if dependencies(of: cell, in: cells).contains(where: { below.contains($0.id) }) {
                result.insert(cell.id)
            }
        }
        return result
    }

    /// Connection-invalidated results and cells reading newer or stale results.
    static func staleCells(in cells: [NrqlCell], invalidated: Set<NrqlCell.ID> = []) -> Set<NrqlCell.ID> {
        var stale = invalidated
        let upstream = Dictionary(uniqueKeysWithValues: cells.map { ($0.id, dependencies(of: $0, in: cells)) })
        var changed: Bool
        repeat {
            changed = false
            for cell in cells where !stale.contains(cell.id) {
                guard let loadedAt = cell.query.loadedAt else { continue }
                if upstream[cell.id, default: []].contains(where: {
                    stale.contains($0.id) || $0.query.loadedAt.map { $0 > loadedAt } == true
                }) {
                    stale.insert(cell.id)
                    changed = true
                }
            }
        } while changed
        return stale
    }

    /// The cells to run, dependencies first, so that `roots` can read what they need.
    /// With `includeFinished` false, a dependency that already has a result (and
    /// whatever it depends on) is left alone unless stale; the roots always run.
    static func plan(
        for roots: [NrqlCell], in cells: [NrqlCell], includeFinished: Bool, stale: Set<NrqlCell.ID> = []
    ) -> [NrqlCell] {
        var visited = Set<NrqlCell.ID>()
        var ordered: [NrqlCell] = []

        func visit(_ cell: NrqlCell) {
            // a cycle ends here; the cell then reports the missing result itself
            guard visited.insert(cell.id).inserted else { return }
            for dependency in dependencies(of: cell, in: cells) {
                if !includeFinished && dependency.query.hasResult && !stale.contains(dependency.id) { continue }
                visit(dependency)
            }
            if cell.isRunnable { ordered.append(cell) }
        }

        roots.forEach(visit)
        return ordered
    }
}
