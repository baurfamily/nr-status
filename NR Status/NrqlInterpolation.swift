//
//  NrqlInterpolation.swift
//  NR Status
//

import Foundation
import LuaSwift

/// Replaces each `{{ expression }}` in a query with the value of the Lua
/// expression, which can read earlier cell results through `results`.
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

    static func expand(_ nrql: String, results: [LuaRuntime.PriorResult] = []) throws -> String {
        let ns = nrql as NSString
        var expanded = ""
        var cursor = 0

        for match in placeholder.matches(in: nrql, range: NSRange(location: 0, length: ns.length)) {
            expanded += ns.substring(with: NSRange(location: cursor, length: match.range.location - cursor))
            let expression = ns.substring(with: match.range(at: 1)).trimmingCharacters(in: .whitespacesAndNewlines)
            expanded += try evaluate(expression, results: results)
            cursor = match.range.location + match.range.length
        }
        return expanded + ns.substring(from: cursor)
    }

    private static func evaluate(_ expression: String, results: [LuaRuntime.PriorResult]) throws -> String {
        let value: LuaValue
        do {
            value = try LuaRuntime.run("return (\(expression))", results: results).value
        } catch {
            throw InterpolationError.evaluation(expression: expression, message: error.localizedDescription)
        }

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
