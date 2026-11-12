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

    /// The cells to run, dependencies first, so that `roots` can read what they need.
    /// With `includeFinished` false, a dependency that already has a result (and
    /// whatever it depends on) is left alone; the roots themselves always run.
    static func plan(for roots: [NrqlCell], in cells: [NrqlCell], includeFinished: Bool) -> [NrqlCell] {
        var visited = Set<NrqlCell.ID>()
        var ordered: [NrqlCell] = []

        func visit(_ cell: NrqlCell) {
            // a cycle ends here; the cell then reports the missing result itself
            guard visited.insert(cell.id).inserted else { return }
            for name in referencedNames(by: cell).sorted() {
                guard let dependency = cells.first(where: { $0.query.name == name && $0.id != cell.id }) else { continue }
                if !includeFinished && dependency.query.resultContainer != nil { continue }
                visit(dependency)
            }
            if cell.isRunnable { ordered.append(cell) }
        }

        roots.forEach(visit)
        return ordered
    }
}
