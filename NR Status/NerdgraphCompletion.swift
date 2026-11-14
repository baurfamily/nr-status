import Foundation

struct NerdgraphSchema: Decodable, Sendable {
    final class TypeReference: Decodable, Sendable {
        let kind: String
        let name: String?
        let ofType: TypeReference?

        var namedType: String? { name ?? ofType?.namedType }
        var displayName: String {
            if kind == "NON_NULL" { return (ofType?.displayName ?? "?") + "!" }
            if kind == "LIST" { return "[" + (ofType?.displayName ?? "?") + "]" }
            return name ?? "?"
        }
    }

    struct Argument: Decodable, Sendable {
        let name: String
        let description: String?
        let type: TypeReference
        let defaultValue: String?
    }

    struct Field: Decodable, Sendable {
        let name: String
        let description: String?
        let args: [Argument]
        let type: TypeReference
    }

    struct NamedType: Decodable, Sendable {
        let name: String
        let kind: String
        let description: String?
        let fields: [Field]?
        let inputFields: [Argument]?
    }

    struct RootType: Decodable, Sendable { let name: String }
    let queryType: RootType
    let mutationType: RootType?
    let subscriptionType: RootType?
    let types: [NamedType]

    func type(named name: String?) -> NamedType? {
        types.first { $0.name == name }
    }

    struct DocumentationTarget: Hashable, Identifiable, Sendable {
        let typeName: String
        var fieldName: String?
        var argumentName: String?

        var id: Self { self }
        var title: String {
            typeName + (fieldName.map { "." + $0 } ?? "")
                + (argumentName.map { "(" + $0 + ":)" } ?? "")
        }
        var anchor: String? {
            guard let fieldName else { return nil }
            return fieldName + (argumentName.map { "." + $0 } ?? "")
        }
    }

    func documentationMatches(_ search: String) -> [DocumentationTarget] {
        let search = search.trimmingCharacters(in: .whitespacesAndNewlines)
        func matches(_ values: String?...) -> Bool {
            values.contains { $0?.localizedCaseInsensitiveContains(search) == true }
        }
        return types.sorted { $0.name < $1.name }.flatMap { type -> [DocumentationTarget] in
            if search.isEmpty { return [DocumentationTarget(typeName: type.name)] }
            var results: [DocumentationTarget] = []
            if matches(type.name, type.description) { results.append(DocumentationTarget(typeName: type.name)) }
            for field in type.fields ?? [] {
                if matches(field.name, field.description, field.type.displayName) {
                    results.append(DocumentationTarget(typeName: type.name, fieldName: field.name))
                }
                for argument in field.args where matches(argument.name, argument.description, argument.type.displayName) {
                    results.append(DocumentationTarget(typeName: type.name, fieldName: field.name, argumentName: argument.name))
                }
            }
            for field in type.inputFields ?? [] where matches(field.name, field.description, field.type.displayName) {
                results.append(DocumentationTarget(typeName: type.name, fieldName: field.name))
            }
            return results
        }
    }

    static var introspectionQuery: String {
        var reference = "kind name"
        for _ in 0..<7 { reference = "kind name ofType { \(reference) }" }
        return """
        query NRStatusSchema {
          __schema {
            queryType { name }
            mutationType { name }
            subscriptionType { name }
            types {
              kind name description
              fields(includeDeprecated: true) {
                name description
                args { name description defaultValue type { \(reference) } }
                type { \(reference) }
              }
              inputFields { name description defaultValue type { \(reference) } }
            }
          }
        }
        """
    }
}

actor NerdgraphSchemaStore {
    private struct Response: Decodable {
        struct SchemaData: Decodable {
            let __schema: NerdgraphSchema
        }
        struct GraphQLError: Decodable { let message: String }
        let data: SchemaData?
        let errors: [GraphQLError]?
    }

    private var cachedConfig: NerdgraphConfig?
    private var cachedSchema: NerdgraphSchema?
    private let session: URLSession

    init(session: URLSession = .shared) { self.session = session }

    func schema(config: NerdgraphConfig) async throws -> NerdgraphSchema {
        if let cachedConfig, cachedConfig.host == config.host, cachedConfig.apiKey == config.apiKey,
           let cachedSchema { return cachedSchema }
        let response: Response = try await NerdgraphClient(config: config, session: session).sendResponse(
            NerdgraphSchema.introspectionQuery, variables: NerdgraphClient.EmptyVariables()
        )
        if let errors = response.errors, !errors.isEmpty {
            throw NerdgraphClient.ClientError.graphQL(errors.map(\.message))
        }
        guard let schema = response.data?.__schema else {
            throw NrqlConnection.ConfigurationError(message: "Nerdgraph did not return its GraphQL schema.")
        }
        cachedConfig = config
        cachedSchema = schema
        return schema
    }
}

enum NerdgraphCompletion {
    private struct Token {
        let text: String
        let range: NSRange
    }

    /// A tolerant lexer: strings and comments never affect selection-set or argument nesting.
    private static func tokens(_ text: String) -> (items: [Token], blocked: Bool) {
        let ns = text as NSString
        var tokens: [Token] = []
        var index = 0
        while index < ns.length {
            let start = index
            let character = ns.character(at: index)
            if character == 35 {
                while index < ns.length, ns.character(at: index) != 10 { index += 1 }
                if index == ns.length { return (tokens, true) }
            } else if character == 34 {
                let block = index + 2 < ns.length && ns.substring(with: NSRange(location: index, length: 3)) == "\"\"\""
                let delimiter = block ? "\"\"\"" : "\""
                index += delimiter.utf16.count
                var closed = false
                while index < ns.length {
                    if ns.character(at: index) == 92 { index = min(index + 2, ns.length); continue }
                    if index + delimiter.utf16.count <= ns.length,
                       ns.substring(with: NSRange(location: index, length: delimiter.utf16.count)) == delimiter {
                        index += delimiter.utf16.count
                        closed = true
                        break
                    }
                    index += 1
                }
                if !closed { return (tokens, true) }
                tokens.append(Token(text: "\"\"", range: NSRange(location: start, length: index - start)))
            } else if isName(character) {
                index += 1
                while index < ns.length, isName(ns.character(at: index)) { index += 1 }
                tokens.append(Token(text: ns.substring(with: NSRange(location: start, length: index - start)),
                                    range: NSRange(location: start, length: index - start)))
            } else {
                index += 1
                if !CharacterSet.whitespacesAndNewlines.contains(UnicodeScalar(character) ?? " ") {
                    tokens.append(Token(text: ns.substring(with: NSRange(location: start, length: 1)),
                                        range: NSRange(location: start, length: 1)))
                }
            }
        }
        return (tokens, false)
    }

    private static func isName(_ character: unichar) -> Bool {
        (65...90).contains(character) || (97...122).contains(character)
            || (48...57).contains(character) || character == 95
    }

    private struct Context {
        let typeName: String?
        let field: NerdgraphSchema.Field?
        let argumentName: String?
        let arguments: [NerdgraphSchema.Argument]
        let inArguments: Bool
        let argumentValue: Bool
        let literalNesting: Int
        let hasSelection: Bool
    }

    private static func context(tokens: [String], schema: NerdgraphSchema) -> Context {
        var root = schema.queryType.name
        var selections: [String?] = []
        var field: NerdgraphSchema.Field?
        var arguments: [NerdgraphSchema.Argument] = []
        var parentheses = 0
        var literalNesting = 0
        var argumentValue = false
        var fragmentType: String?
        var expectsFragmentType = false
        var directive = false
        var argumentName: String?
        for (index, token) in tokens.enumerated() {
            if token == "mutation", selections.isEmpty { root = schema.mutationType?.name ?? "" }
            if token == "subscription", selections.isEmpty { root = schema.subscriptionType?.name ?? "" }
            if token == "(" {
                if parentheses == 0 {
                    arguments = directive ? [] : field?.args ?? []
                    argumentValue = false
                    argumentName = nil
                }
                parentheses += 1
            } else if token == ")" {
                parentheses = max(0, parentheses - 1)
                if parentheses == 0 { directive = false }
            } else if parentheses > 0 {
                if token == "{" || token == "[" { literalNesting += 1 }
                if token == "}" || token == "]" { literalNesting = max(0, literalNesting - 1) }
                if parentheses == 1, literalNesting == 0 {
                    if token == ":" { argumentValue = true }
                    if token == "," { argumentValue = false; argumentName = nil }
                    if arguments.contains(where: { $0.name == token }) {
                        if tokens.indices.contains(index + 1), tokens[index + 1] == ":" {
                            argumentName = token
                            argumentValue = false
                        } else if !argumentValue {
                            argumentName = token
                        }
                    }
                }
            } else if token == "@" {
                directive = true
            } else if directive {
                directive = false
            } else if token == "on" {
                expectsFragmentType = true
            } else if expectsFragmentType {
                fragmentType = token
                expectsFragmentType = false
            } else if token == "{" {
                selections.append(fragmentType ?? (selections.isEmpty ? root : field?.type.namedType))
                fragmentType = nil
                field = nil
            } else if token == "}" {
                if !selections.isEmpty { selections.removeLast() }
                field = nil
            } else if let type = selections.last {
                field = schema.type(named: type)?.fields?.first { $0.name == token }
            }
        }
        return Context(
            typeName: fragmentType ?? (selections.last ?? root), field: field,
            argumentName: parentheses > 0 ? argumentName : nil, arguments: arguments,
            inArguments: parentheses > 0, argumentValue: argumentValue, literalNesting: literalNesting,
            hasSelection: !selections.isEmpty
        )
    }

    static func documentationTarget(text: String, location: Int, schema: NerdgraphSchema) -> NerdgraphSchema.DocumentationTarget? {
        let ns = text as NSString
        var end = min(max(location, 0), ns.length)
        while end < ns.length, isName(ns.character(at: end)) { end += 1 }
        var next = end
        while next < ns.length, let character = UnicodeScalar(ns.character(at: next)),
              CharacterSet.whitespacesAndNewlines.contains(character) { next += 1 }
        if next < ns.length, ns.character(at: next) == 58 { end = next + 1 }
        let context = context(tokens: tokens(ns.substring(to: end)).items.map(\.text), schema: schema)
        guard let typeName = context.typeName, schema.type(named: typeName) != nil else { return nil }
        return NerdgraphSchema.DocumentationTarget(
            typeName: typeName, fieldName: context.field?.name, argumentName: context.argumentName
        )
    }

    static func items(text: String, location: Int, schema: NerdgraphSchema) -> (items: [NrqlCompletion.Item], range: NSRange) {
        let ns = text as NSString
        let end = min(max(location, 0), ns.length)
        var start = end
        while start > 0, isName(ns.character(at: start - 1)) { start -= 1 }
        let range = NSRange(location: start, length: end - start)
        let prefix = ns.substring(with: range)
        let lexed = tokens(ns.substring(to: start))
        guard !lexed.blocked else { return ([], range) }
        let tokens = lexed.items.map(\.text)

        func matching(_ items: [NrqlCompletion.Item]) -> (items: [NrqlCompletion.Item], range: NSRange) {
            (items.filter { $0.name.hasPrefix(prefix) }.sorted { $0.name < $1.name }, range)
        }
        if tokens.last == "$" {
            let pattern = try? NSRegularExpression(pattern: #"\$([A-Za-z_][A-Za-z0-9_]*)\s*:"#)
            let names = pattern?.matches(in: text, range: NSRange(location: 0, length: ns.length)).compactMap {
                Range($0.range(at: 1), in: text).map { String(text[$0]) }
            } ?? []
            return matching(Set(names).map { .init(name: $0, kind: .variable, detail: "GraphQL variable", insertText: $0) })
        }
        if tokens.last == "on" {
            return matching(schema.types.filter { ["OBJECT", "INTERFACE", "UNION"].contains($0.kind) }.map {
                .init(name: $0.name, kind: .field, detail: $0.description, insertText: $0.name)
            })
        }
        let context = context(tokens: tokens, schema: schema)
        if context.inArguments {
            guard !context.argumentValue, context.literalNesting == 0 else { return ([], range) }
            return matching(context.arguments.map {
                .init(name: $0.name, kind: .field, detail: "\($0.type.displayName)\n\($0.description ?? "")",
                      insertText: $0.name + ": ")
            })
        }
        guard context.hasSelection else {
            return matching(["query", "mutation", "fragment"].map {
                .init(name: $0, kind: .keyword, detail: "GraphQL", insertText: $0 + " ")
            })
        }
        var items = (schema.type(named: context.typeName)?.fields ?? []).map { field in
            let arguments = field.args.map { "\($0.name): \($0.type.displayName)" }.joined(separator: ", ")
            return NrqlCompletion.Item(
                name: field.name, kind: .field,
                detail: field.name + (arguments.isEmpty ? "" : "(\(arguments))") + ": \(field.type.displayName)"
                    + (field.description.map { "\n" + $0 } ?? ""),
                insertText: field.name
            )
        }
        items.append(.init(name: "__typename", kind: .field, detail: "The concrete GraphQL type name.", insertText: "__typename"))
        return matching(items)
    }
}
