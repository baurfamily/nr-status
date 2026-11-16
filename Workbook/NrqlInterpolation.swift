//
//  NrqlInterpolation.swift
//  NR Status
//

import Foundation
import LuaSwift

/// Replaces each `{{ expression }}` in a query with the value of the Lua
/// expression, which can read `results` and the effective document `config`.
enum NrqlInterpolation {
    enum InterpolationError: LocalizedError {
        case evaluation(expression: String, message: String)
        case noValue(expression: String)
        case notText(expression: String)

        var errorDescription: String? {
            switch self {
            case .evaluation(let expression, let message): "{{ \(expression) }}: \(message)"
            case .noValue(let expression): "{{ \(expression) }} has no value. Has the cell it reads been run?"
            case .notText(let expression): "{{ \(expression) }} must be a string, number or boolean."
            }
        }
    }

    private static let placeholder = try! NSRegularExpression(
        pattern: #"\{\{(.*?)\}\}"#,
        options: [.dotMatchesLineSeparators]
    )

    static func containsPlaceholders(_ nrql: String) -> Bool {
        placeholder.firstMatch(in: nrql, range: NSRange(nrql.startIndex..., in: nrql)) != nil
    }

    /// The text of each `{{ }}` expression, untrimmed.
    static func expressions(in nrql: String) -> [String] {
        placeholder.matches(in: nrql, range: NSRange(nrql.startIndex..., in: nrql)).compactMap {
            Range($0.range(at: 1), in: nrql).map { String(nrql[$0]) }
        }
    }

    static func expand(
        _ nrql: String, results: [LuaRuntime.PriorResult] = [], config: NrqlConnection = NrqlConnection()
    ) throws -> String {
        let ns = nrql as NSString
        var expanded = ""
        var cursor = 0

        for match in placeholder.matches(in: nrql, range: NSRange(location: 0, length: ns.length)) {
            expanded += ns.substring(with: NSRange(location: cursor, length: match.range.location - cursor))
            let expression = ns.substring(with: match.range(at: 1)).trimmingCharacters(in: .whitespacesAndNewlines)
            expanded += try evaluate(expression, results: results, config: config)
            cursor = match.range.location + match.range.length
        }
        return expanded + ns.substring(from: cursor)
    }

    /// Outside JSON strings a placeholder inserts a typed JSON value; inside strings it inserts escaped text.
    static func expandJSON(
        _ text: String, results: [LuaRuntime.PriorResult] = [], config: NrqlConnection = NrqlConnection()
    ) throws -> JSONValue {
        let ns = text as NSString
        var expanded = ""
        var cursor = 0
        var inString = false
        var escaped = false
        for match in placeholder.matches(in: text, range: NSRange(location: 0, length: ns.length)) {
            let segment = ns.substring(with: NSRange(location: cursor, length: match.range.location - cursor))
            for character in segment {
                if escaped { escaped = false }
                else if character == "\\", inString { escaped = true }
                else if character == "\"" { inString.toggle() }
            }
            expanded += segment
            let expression = ns.substring(with: match.range(at: 1)).trimmingCharacters(in: .whitespacesAndNewlines)
            let value = try evaluateValue(expression, results: results, config: config)
            if case .nil = value { throw InterpolationError.noValue(expression: expression) }
            if inString {
                let string = try textual(value, expression: expression)
                let quoted = try JSONValue.string(string).encodedText()
                expanded += quoted.dropFirst().dropLast()
            } else {
                expanded += try JSONValue(luaValue: value).encodedText()
            }
            cursor = NSMaxRange(match.range)
        }
        expanded += ns.substring(from: cursor)
        let value = try JSONDecoder().decode(JSONValue.self, from: Data(expanded.utf8))
        guard case .object = value else {
            throw NrqlConnection.ConfigurationError(message: "GraphQL variables must be a JSON object.")
        }
        return value
    }

    private static func evaluateValue(
        _ expression: String, results: [LuaRuntime.PriorResult], config: NrqlConnection
    ) throws -> LuaValue {
        do {
            return try LuaRuntime.run("return (\(expression))", results: results, config: config).value
        } catch {
            throw InterpolationError.evaluation(expression: expression, message: error.localizedDescription)
        }
    }

    private static func evaluate(
        _ expression: String, results: [LuaRuntime.PriorResult], config: NrqlConnection
    ) throws -> String {
        try textual(evaluateValue(expression, results: results, config: config), expression: expression)
    }

    private static func textual(_ value: LuaValue, expression: String) throws -> String {
        switch value {
        case .nil: throw InterpolationError.noValue(expression: expression)
        case .string(let string): return string
        case .bool(let flag): return flag ? "true" : "false"
        case .number(let number):
            return number == number.rounded() && abs(number) < 1e15 ? String(Int(number)) : String(number)
        default: throw InterpolationError.notText(expression: expression)
        }
    }
}
