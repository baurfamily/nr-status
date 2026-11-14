import Foundation

/// The two editors belong to one cell; only the variables fence follows the query fence.
struct NerdgraphCellSource {
    var query: String
    var variables: String
    var hasVariables: Bool
    var isClosed = true

    private static let separator = "\n```variables\n"

    init(editorText: String) {
        if let range = editorText.range(of: Self.separator) {
            query = String(editorText[..<range.lowerBound])
            variables = String(editorText[range.upperBound...])
            hasVariables = true
        } else {
            query = editorText
            variables = "{}"
            hasVariables = false
        }
    }

    init(stored: String) {
        let lines = stored.components(separatedBy: "\n")
        guard let open = lines.firstIndex(where: { NrqlCellKind.fenced(by: $0) == .nerdgraph }) else {
            self.init(editorText: stored)
            return
        }
        let close = lines.indices.first { $0 > open && NrqlCellKind.isClosingFence(lines[$0]) }
        self.init(editorText: lines[(open + 1)..<(close ?? lines.endIndex)].joined(separator: "\n"))
        isClosed = close != nil
        if let close, let variablesOpen = lines.indices.first(where: {
            $0 > close && lines[$0].trimmingCharacters(in: .whitespaces).lowercased() == "```variables"
        }) {
            hasVariables = true
            let variablesClose = lines.indices.first { $0 > variablesOpen && NrqlCellKind.isClosingFence(lines[$0]) }
            variables = lines[(variablesOpen + 1)..<(variablesClose ?? lines.endIndex)].joined(separator: "\n")
            isClosed = variablesClose != nil
        }
    }

    var editorText: String { query + (hasVariables ? Self.separator + variables : "") }
    var storedText: String {
        "```graphql\n\(query)\n```" + (hasVariables ? "\n```variables\n\(variables)\n```" : "")
    }

    var metadata: String {
        query.components(separatedBy: "\n")
            .prefix { line in
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                return trimmed.isEmpty || trimmed.hasPrefix("#")
            }
            .compactMap { line -> String? in
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                guard trimmed.hasPrefix("#") else { return nil }
                return trimmed.dropFirst().trimmingCharacters(in: .whitespaces)
            }
            .joined(separator: "\n")
    }

    private var variableDeclarations: [String] {
        metadata.components(separatedBy: "\n").compactMap { line in
            guard let colon = line.firstIndex(of: ":"),
                  line[..<colon].trimmingCharacters(in: .whitespaces).lowercased() == "var" else { return nil }
            let value = line[line.index(after: colon)...].trimmingCharacters(in: .whitespaces)
            return value.isEmpty ? nil : value
        }
    }

    func resultBindings() throws -> [LuaRuntime.Variable] {
        var names = Set<String>()
        return try variableDeclarations.map { declaration in
            let variable = try LuaRuntime.Variable.parse(declaration)
            guard names.insert(variable.name).inserted else {
                throw NrqlConnection.ConfigurationError(message: "Duplicate Nerdgraph variable '\(variable.name)'.")
            }
            return variable
        }
    }

    var bindingNames: [String] {
        variableDeclarations.compactMap { try? LuaRuntime.Variable.parse($0).name }
    }

    var bindingExpressions: [String] {
        variableDeclarations.compactMap { try? LuaRuntime.Variable.parse($0).expression }
    }

    var format: ChartFormat? {
        guard !metadata.isEmpty else { return nil }
        var format = ChartFormat.parseMetadata(metadata)
        format.name = bindingNames.first
        return format
    }
    var operation: String { query }
}
