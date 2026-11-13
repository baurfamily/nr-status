//
//  NrqlDependencies.swift
//  NR Status
//

import Foundation

/// Which cells read which other cells' results, found by scanning the `{{ }}`
/// expressions of a query, or the whole of a script, for `results.<name>`.
enum NrqlDependencies {
    private static let references = [
        try! NSRegularExpression(pattern: #"\bresults\s*\.\s*([A-Za-z_][A-Za-z0-9_]*)"#),
        try! NSRegularExpression(pattern: #"\bresults\s*\[\s*["']([^"']+)["']\s*\]"#),
    ]

    static func referencedNames(by cell: NrqlCell) -> Set<String> {
        let code = cell.query.script ?? NrqlInterpolation.expressions(in: cell.query.nrql).joined(separator: "\n")
        let range = NSRange(code.startIndex..., in: code)
        var names = Set<String>()
        for pattern in references {
            for match in pattern.matches(in: code, range: range) {
                if let nameRange = Range(match.range(at: 1), in: code) { names.insert(String(code[nameRange])) }
            }
        }
        return names
    }

    /// The cells whose results `cell` reads.
    static func dependencies(of cell: NrqlCell, in cells: [NrqlCell]) -> [NrqlCell] {
        referencedNames(by: cell).sorted().compactMap { name in
            cells.first { $0.query.name == name && $0.id != cell.id }
        }
    }

    /// Cells whose result is out of date: a cell they read has produced a newer
    /// result since they ran, or is itself out of date.
    static func staleCells(in cells: [NrqlCell]) -> Set<NrqlCell.ID> {
        var stale = Set<NrqlCell.ID>()
        var resolved = Set<NrqlCell.ID>()

        func check(_ cell: NrqlCell, path: inout Set<NrqlCell.ID>) -> Bool {
            if resolved.contains(cell.id) { return stale.contains(cell.id) }
            guard path.insert(cell.id).inserted else { return false }
            defer { path.remove(cell.id) }

            var isStale = false
            if let loadedAt = cell.query.loadedAt {
                for dependency in dependencies(of: cell, in: cells) {
                    let dependencyStale = check(dependency, path: &path)
                    let newer = dependency.query.loadedAt.map { $0 > loadedAt } ?? false
                    if dependencyStale || newer { isStale = true }
                }
            }
            resolved.insert(cell.id)
            if isStale { stale.insert(cell.id) }
            return isStale
        }

        for cell in cells {
            var path = Set<NrqlCell.ID>()
            _ = check(cell, path: &path)
        }
        return stale
    }

    /// The cells to run, dependencies first, so that `roots` can read what they need.
    /// With `includeFinished` false, a dependency that already has a result (and
    /// whatever it depends on) is left alone; the roots themselves always run.
    static func plan(for roots: [NrqlCell], in cells: [NrqlCell], includeFinished: Bool) -> [NrqlCell] {
        var visited = Set<NrqlCell.ID>()
        var ordered: [NrqlCell] = []

        func visit(_ cell: NrqlCell) {
            // a cycle ends here; the cell then reports the missing result itself
            guard visited.insert(cell.id).inserted else { return }
            for dependency in dependencies(of: cell, in: cells) {
                if !includeFinished && dependency.query.resultContainer != nil { continue }
                visit(dependency)
            }
            if cell.isRunnable { ordered.append(cell) }
        }

        roots.forEach(visit)
        return ordered
    }
}
