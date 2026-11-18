import Foundation

/// The query and variables belong to one cell; only the variables fence follows the query fence.
struct NerdgraphCellSource {
    var query: String
    var variables: String
    var hasVariables: Bool
    var isClosed = true
    var configuration: String?

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
        let source = NrqlCellSource(stored: stored)
        let lines = source.code.components(separatedBy: "\n")
        guard let open = lines.firstIndex(where: { NrqlCellKind.fenced(by: $0) == .nerdgraph }) else {
            self.init(editorText: stored)
            return
        }
        let close = lines.indices.first { $0 > open && NrqlCellKind.isClosingFence(lines[$0]) }
        self.init(editorText: lines[(open + 1)..<(close ?? lines.endIndex)].joined(separator: "\n"))
        configuration = source.configuration
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
        NrqlCellSource(
            configuration: configuration,
            code: "```graphql\n\(query)\n```" + (hasVariables ? "\n```variables\n\(variables)\n```" : "")
        ).storedText
    }

    var metadata: String {
        configuration ?? ""
    }

    var extractionBindings: [LuaRuntime.Variable] {
        LuaRuntime.Variable.editableBindings(in: metadata)
    }

    static func updatingExtractions(_ bindings: [LuaRuntime.Variable], in metadata: String) throws -> String {
        try LuaRuntime.Variable.updatingBindings(bindings, in: metadata)
    }

    func resultBindings() throws -> [LuaRuntime.Variable] {
        let yaml = try ConfigurationYAML(metadata)
        var bindings: [LuaRuntime.Variable] = []
        if let name = try NrqlCellSource.resultName(in: metadata) {
            bindings.append(.init(name: name, expression: nil))
        }
        bindings += try yaml.mappings("bindings").map(LuaRuntime.Variable.parse)
        var names = Set<String>()
        for binding in bindings {
            guard names.insert(binding.name).inserted else {
                throw NrqlConnection.ConfigurationError(message: "Duplicate Nerdgraph variable '\(binding.name)'.")
            }
        }
        return bindings
    }

    var bindingNames: [String] {
        [try? NrqlCellSource.resultName(in: metadata)].compactMap { $0 }
            + extractionBindings.map(\.name).filter { !$0.isEmpty }
    }

    var bindingExpressions: [String] {
        extractionBindings.compactMap(\.expression)
    }

    var format: ChartFormat? {
        guard configuration != nil else { return nil }
        var format = ChartFormat.parseMetadata(metadata)
        format.name = try? NrqlCellSource.resultName(in: metadata)
        return format
    }
    var operation: String { query }
}
