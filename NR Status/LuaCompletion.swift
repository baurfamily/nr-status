//
//  LuaCompletion.swift
//  NR Status
//

import Foundation
import LuaSwift

/// Completion for the Lua in script cells and in `{{ }}` expressions inside queries.
/// Like `NrqlCompletion` the analysis is purely textual, so it is fast and testable.
enum LuaCompletion {
    /// What a script can see of the rest of the notebook.
    struct Scope {
        /// Names of the other named cells, whether or not they have run.
        var names: [String] = []
        /// Results of the named cells that have run.
        var results: [LuaRuntime.PriorResult] = []
        var variables: [String] = []
        var revision = ""

        static let empty = Scope()
    }

    private static let statementKeywords = [
        "break", "do", "else", "elseif", "end", "for", "function", "goto", "if", "in", "local", "repeat", "return",
        "then", "until", "while",
    ]
    private static let valueKeywords = ["and", "or", "not", "nil", "true", "false"]

    private static let globalFunctions = [
        "emit", "print", "pairs", "ipairs", "tostring", "tonumber", "type", "select", "pcall", "error", "assert",
    ]
    private static let globalTables = ["config", "results", "string", "table", "math"]

    private static let library: [String: [String]] = [
        "string": ["byte", "char", "find", "format", "gmatch", "gsub", "len", "lower", "match", "rep", "reverse", "sub", "upper"],
        "table": ["concat", "insert", "remove", "sort", "unpack"],
        "math": [
            "abs", "ceil", "cos", "exp", "floor", "huge", "log", "max", "min", "pi", "random", "sin", "sqrt", "tan",
        ],
    ]
    private static let libraryConstants: Set<String> = ["huge", "pi"]

    /// What a query result table holds, for results that haven't run yet.
    private static let resultFields = ["columns", "nrql", "rows"]

    // MARK: - Interpolation

    /// Where the expression begins when the position is inside an unclosed `{{ }}`.
    static func interpolationStart(in text: String, at location: Int) -> Int? {
        let ns = text as NSString
        let upToCursor = ns.substring(to: min(max(location, 0), ns.length))
        guard let open = upToCursor.range(of: "{{", options: .backwards) else { return nil }
        if let close = upToCursor.range(of: "}}", options: .backwards), close.lowerBound >= open.lowerBound {
            return nil
        }
        return upToCursor.distance(from: upToCursor.startIndex, to: open.upperBound)
    }

    // MARK: - Items

    private enum Step: Equatable {
        case name(String)
        case index(Int)
    }

    private static let steps = try! NSRegularExpression(pattern: #"([A-Za-z_][A-Za-z0-9_]*)|\[(\d+)\]"#)

    private static let declarations = [
        try! NSRegularExpression(pattern: #"\blocal\s+function\s+([A-Za-z_][A-Za-z0-9_]*)"#),
        try! NSRegularExpression(pattern: #"\blocal\s+([A-Za-z_][A-Za-z0-9_]*(?:\s*,\s*[A-Za-z_][A-Za-z0-9_]*)*)"#),
        try! NSRegularExpression(pattern: #"\bfunction\s+([A-Za-z_][A-Za-z0-9_]*)"#),
        try! NSRegularExpression(
            pattern: #"\bfor\s+([A-Za-z_][A-Za-z0-9_]*(?:\s*,\s*[A-Za-z_][A-Za-z0-9_]*)*)\s*(?:in\b|=)"#
        ),
    ]

    private static func isWordCharacter(_ char: unichar) -> Bool {
        guard let scalar = Unicode.Scalar(char) else { return false }
        return CharacterSet.alphanumerics.contains(scalar) || char == 0x5F
    }

    /// `isExpression` is true inside `{{ }}`, where only a value can be written.
    static func items(
        text: String, location: Int, scope: Scope, isExpression: Bool = false
    ) -> (items: [NrqlCompletion.Item], range: NSRange) {
        let ns = text as NSString
        let cursor = min(max(location, 0), ns.length)

        var start = cursor
        while start > 0, isWordCharacter(ns.character(at: start - 1)) { start -= 1 }
        let range = NSRange(location: start, length: cursor - start)
        let prefix = ns.substring(with: range)
        let none: (items: [NrqlCompletion.Item], range: NSRange) = ([], range)

        let lineStart = ns.lineRange(for: NSRange(location: start, length: 0)).location
        let lineBefore = ns.substring(with: NSRange(location: lineStart, length: start - lineStart))
        if lineBefore.contains("--") { return none }
        // inside a string
        for quote in ["\"", "'"] where lineBefore.components(separatedBy: quote).count % 2 == 0 { return none }

        var candidates: [NrqlCompletion.Item]
        if start > 0, ns.character(at: start - 1) == 0x2E {
            guard let chain = chain(in: ns, endingAt: start - 1) else { return none }
            candidates = members(of: chain, scope: scope)
        } else {
            candidates = globals(text: text, prefix: prefix, scope: scope, isExpression: isExpression)
        }

        let lowered = prefix.lowercased()
        let matching = candidates.filter { lowered.isEmpty || $0.name.lowercased().hasPrefix(lowered) }
        return (matching, range)
    }

    /// The names and indexes of `results.top_app.rows[1]` before a trailing dot at `dot`.
    private static func chain(in ns: NSString, endingAt dot: Int) -> [Step]? {
        var begin = dot
        while begin > 0 {
            let char = ns.character(at: begin - 1)
            guard isWordCharacter(char) || char == 0x2E || char == 0x5B || char == 0x5D else { break }
            begin -= 1
        }
        let expression = ns.substring(with: NSRange(location: begin, length: dot - begin))
        guard !expression.isEmpty, !expression.hasPrefix("."), !expression.contains("..") else { return nil }

        let matches = steps.matches(in: expression, range: NSRange(location: 0, length: (expression as NSString).length))
        let parsed = matches.compactMap { match -> Step? in
            let source = expression as NSString
            if match.range(at: 1).location != NSNotFound { return .name(source.substring(with: match.range(at: 1))) }
            return Int(source.substring(with: match.range(at: 2))).map(Step.index)
        }
        guard case .name = parsed.first else { return nil }
        return parsed
    }

    private static func item(_ name: String, _ kind: NrqlCompletion.Kind, detail: String? = nil, insert: String? = nil)
        -> NrqlCompletion.Item
    {
        NrqlCompletion.Item(name: name, kind: kind, detail: detail, insertText: insert ?? name)
    }

    private static func globals(text: String, prefix: String, scope: Scope, isExpression: Bool) -> [NrqlCompletion.Item] {
        var items: [NrqlCompletion.Item] = []
        if !isExpression {
            items += locals(in: text).filter { $0 != prefix }.map { item($0, .variable, detail: "local") }
        }
        items += globalTables.map { item($0, .variable) }
        items += globalFunctions.map { item($0, .function, insert: "\($0)(") }
        items += valueKeywords.map { item($0, .keyword) }
        if !isExpression { items += statementKeywords.map { item($0, .keyword) } }
        return items
    }

    private static func locals(in text: String) -> [String] {
        let range = NSRange(location: 0, length: (text as NSString).length)
        var names: [String] = []
        for regex in declarations {
            for match in regex.matches(in: text, range: range) {
                let list = (text as NSString).substring(with: match.range(at: 1))
                names += list.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
            }
        }
        return Array(Set(names)).sorted()
    }

    private static func members(of chain: [Step], scope: Scope) -> [NrqlCompletion.Item] {
        guard case .name(let root) = chain[0] else { return [] }

        if root == "config", chain.count == 1 {
            return [
                item("accounts", .field, detail: "Document account IDs (1-based list)"),
                item("api_key", .field, detail: "Saved document API key name, not the secret")
            ] + scope.variables.map { item($0, .field, detail: "document variable") }
        }

        if root == "results" {
            if chain.count == 1 {
                return scope.names.map { item($0, .field, detail: "result") }
            }
            guard case .name(let name) = chain[1] else { return [] }
            guard let value = scope.results.first(where: { $0.name == name })?.value else {
                return chain.count == 2 && scope.names.contains(name) ? resultFields.map { item($0, .field) } : []
            }
            return fields(of: walk(value, chain.dropFirst(2)))
        }

        if chain.count == 1, let words = library[root] {
            return words.map {
                libraryConstants.contains($0) ? item($0, .variable, detail: "number") : item($0, .function, insert: "\($0)(")
            }
        }
        return []
    }

    private static func walk(_ value: LuaValue, _ steps: ArraySlice<Step>) -> LuaValue? {
        var current = value
        for step in steps {
            switch (step, current) {
            case (.name(let key), .table(let table)):
                guard let next = table[key] else { return nil }
                current = next
            case (.index(let index), .array(let items)):
                guard items.indices.contains(index - 1) else { return nil }
                current = items[index - 1]
            default:
                return nil
            }
        }
        return current
    }

    private static func fields(of value: LuaValue?) -> [NrqlCompletion.Item] {
        guard case .table(let table)? = value else { return [] }
        return table.keys.sorted().map { item($0, .field, detail: describe(table[$0])) }
    }

    private static func describe(_ value: LuaValue?) -> String? {
        switch value {
        case .string?: "string"
        case .number?: "number"
        case .bool?: "boolean"
        case .table?: "table"
        case .array?: "list"
        default: nil
        }
    }
}
