import Foundation

enum WorkbookWidgetRunner {
    static func plan(target: NrqlCell, in cells: [NrqlCell]) throws -> [NrqlCell] {
        guard target.canPublishWidget else {
            throw NrqlConnection.ConfigurationError(message: "Publish a chart or Markdown cell.")
        }
        var visiting = Set<UUID>()
        var finished = Set<UUID>()
        var order: [NrqlCell] = []

        func visit(_ cell: NrqlCell) throws {
            guard !finished.contains(cell.id) else { return }
            guard visiting.insert(cell.id).inserted else {
                throw NrqlConnection.ConfigurationError(message: "Widget dependency cycle at '\(cell.query.title)'.")
            }
            // Positional and computed references cannot identify a minimal dependency graph.
            let expressions = cell.query.expressionCode
            let withoutNamedReferences = expressions
                .replacingOccurrences(of: #"\bresults\s*\[\s*["'][^"']+["']\s*\]"#, with: "", options: .regularExpression)
                .replacingOccurrences(of: #"\bresults\s*\.\s*[A-Za-z_][A-Za-z0-9_]*"#, with: "", options: .regularExpression)
            if withoutNamedReferences.range(of: #"\bresults\b"#, options: .regularExpression) != nil {
                throw NrqlConnection.ConfigurationError(message: "Widget dependencies must use results.name or results[\"name\"].")
            }
            if cell.kind == .nerdgraph,
               cell.query.nrql.range(of: #"(?m)^\s*(mutation|subscription)\b"#, options: .regularExpression) != nil {
                throw NrqlConnection.ConfigurationError(message: "Widgets can only run read-only Nerdgraph queries.")
            }
            for name in NrqlDependencies.referencedNames(by: cell).sorted() {
                let sources = cells.filter { $0.query.resultNames.contains(name) }
                guard sources.count == 1, let source = sources.first else {
                    throw NrqlConnection.ConfigurationError(
                        message: sources.isEmpty ? "Missing widget dependency '\(name)'." : "Ambiguous widget dependency '\(name)'."
                    )
                }
                try visit(source)
            }
            visiting.remove(cell.id)
            finished.insert(cell.id)
            if cell.isRunnable { order.append(cell) }
        }
        try visit(target)
        return order
    }

    @MainActor static func run(
        _ widget: PublishedWidget, profiles: NerdgraphProfiles = .shared, session: URLSession = .shared
    ) async throws -> WorkbookWidgetOutput {
        let document = NRQL_EditorDocument(text: widget.workbook)
        let targets = document.cells.filter { $0.widgetID == widget.id }
        guard targets.count == 1, let target = targets.first else {
            throw NrqlConnection.ConfigurationError(message: "The published cell is missing or has a duplicate widget-id.")
        }
        let defaults = try document.connection.get()
        let order = try plan(target: target, in: document.cells)
        for cell in order {
            try Task.checkCancellation()
            await cell.query.getData(results: document.priorResults, defaults: defaults, profiles: profiles, session: session)
            try Task.checkCancellation()
            if let error = cell.query.errorMessage {
                throw NrqlConnection.ConfigurationError(message: "\(cell.query.title): \(error)")
            }
            if let errors = cell.query.jsonResult?.graphQLErrors, !errors.isEmpty {
                throw NrqlConnection.ConfigurationError(message: "\(cell.query.title): \(errors.joined(separator: "; "))")
            }
        }
        var output = WorkbookWidgetOutput(title: widget.name, updatedAt: Date())
        if target.kind == .markdown {
            output.markdown = try document.markdownText(for: target, profiles: profiles.load())
        } else {
            guard let container = target.query.resultContainer else {
                throw NrqlConnection.ConfigurationError(message: "The published cell returned no chart data.")
            }
            output.chart = try JSONValue(luaValue: LuaResultBridge.luaValue(from: container))
            output.configuration = target.configurationText
        }
        return output
    }
}
