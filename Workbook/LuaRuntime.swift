//
//  LuaRuntime.swift
//  NR Status
//

import Foundation
import LuaSwift

/// Runs one Lua script in a fresh, sandboxed VM. A script supplies its result
/// either with a `return` statement or by calling `emit(value)`; `emit` wins.
struct LuaRuntime {
    static let instructionLimit = 10_000_000
    static let memoryLimit = 64_000_000

    struct Outcome {
        var value: LuaValue
        var output: [String]
    }

    /// Earlier cell results, available to scripts as `results.<name>` and `results[<index>]`.
    struct PriorResult {
        var name: String?
        var value: LuaValue
    }

    struct Variable: Equatable, Sendable {
        let name: String
        let expression: String?

        static func parse(_ text: String, requiresExpression: Bool = false) throws -> Variable {
            let parts = text.split(separator: "=", maxSplits: 1, omittingEmptySubsequences: false)
            let name = parts.first?.trimmingCharacters(in: .whitespaces) ?? ""
            let isIdentifier = name.range(of: #"^[A-Za-z_][A-Za-z0-9_]*$"#, options: .regularExpression) != nil
                && !keywords.contains(name)
            guard !name.isEmpty, !requiresExpression || isIdentifier else {
                throw NrqlConnection.ConfigurationError(message: "Invalid variable name '\(name)'.")
            }
            let expression = parts.count == 2 ? parts[1].trimmingCharacters(in: .whitespaces) : nil
            guard expression != "", !requiresExpression || expression != nil else {
                throw NrqlConnection.ConfigurationError(message: "Variable '\(name)' requires an expression after '='.")
            }
            return Variable(name: name, expression: expression)
        }
    }

    private static let keywords: Set<String> = [
        "and", "break", "do", "else", "elseif", "end", "false", "for", "function", "goto", "if",
        "in", "local", "nil", "not", "or", "repeat", "return", "then", "true", "until", "while"
    ]
    static let reservedConfigFields: Set<String> = ["accounts", "api_key"]

    // `results` is a plain table (so a missing name is nil) behind a read-only proxy.
    private static let resultsPrelude = """
    local data = __results()
    __results = nil
    local copy = {}
    for index, value in ipairs(data.list) do copy[index] = value end
    for name, value in pairs(data.named) do copy[name] = value end
    results = setmetatable({}, {
        __index = copy,
        __len = function() return #data.list end,
        __newindex = function() error("results is read-only", 2) end,
    })
    """

    private static let configPrelude = """
    config = __config()
    __config = nil
    """

    private static let configReference = try! NSRegularExpression(pattern: #"\bconfig\b"#)

    static func referencesConfiguration(in code: String) -> Bool {
        configReference.firstMatch(in: code, range: NSRange(code.startIndex..., in: code)) != nil
    }

    // The Lua engine isn't safe to run from several threads at once, so runs take turns.
    private static let runLock = NSLock()

    static func run(
        _ script: String, results: [PriorResult] = [], config: NrqlConnection = NrqlConnection(),
        response: JSONValue? = nil
    ) throws -> Outcome {
        runLock.lock()
        defer { runLock.unlock() }
        return try runLocked(script, results: results, config: config, response: response)
    }

    private static func runLocked(
        _ script: String, results: [PriorResult], config: NrqlConnection, response: JSONValue?
    ) throws -> Outcome {
        let engine = try LuaEngine(
            configuration: LuaEngineConfiguration(sandboxed: true, vmMemoryLimit: memoryLimit)
        )
        engine.setInstructionLimit(instructionLimit)

        // Callbacks may run on another thread, so collect through a box.
        final class Collected: @unchecked Sendable {
            var emitted: LuaValue?
            var output: [String] = []
        }
        let collected = Collected()

        let resultsTable = LuaValue.table([
            "list": .array(results.map(\.value)),
            "named": .table(
                results.reduce(into: [:]) { table, result in
                    if let name = result.name { table[name] = result.value }
                }
            ),
        ])
        var fields: [String: LuaValue] = [
            "accounts": .array((config.accountIds ?? []).map { .number(Double($0)) })
        ]
        if let name = config.apiKeyName { fields["api_key"] = .string(name) }
        let configTable = LuaValue.table(fields)
        engine.registerFunction(name: "__config") { _ in configTable }
        try engine.run(configPrelude)

        for variable in config.variables {
            guard let expression = variable.expression else {
                throw NrqlConnection.ConfigurationError(message: "Variable '\(variable.name)' requires an expression.")
            }
            do {
                let value = try engine.evaluate("return (\(expression))")
                if case .nil = value {
                    throw NrqlConnection.ConfigurationError(message: "The expression has no value.")
                }
                _ = try JSONValue(luaValue: value)
                engine.registerFunction(name: "__variable") { _ in value }
                try engine.run("local value = __variable(); __variable = nil; config.\(variable.name) = value")
            } catch {
                throw NrqlConnection.ConfigurationError(message: "Config variable '\(variable.name)': \(error.localizedDescription)")
            }
        }
        engine.registerFunction(name: "__results") { _ in resultsTable }
        try engine.run(resultsPrelude)
        if let response {
            let value = response.luaValue
            engine.registerFunction(name: "__response") { _ in value }
            try engine.run("local response = __response(); __response = nil; data = response.data; errors = response.errors; extensions = response.extensions")
        }

        engine.registerFunction(name: "emit") { arguments in
            collected.emitted = arguments.first ?? .nil
            return .nil
        }
        engine.registerFunction(name: "print") { arguments in
            collected.output.append(arguments.map(\.asString).joined(separator: "\t"))
            return .nil
        }

        let returned = try engine.evaluate(script)
        return Outcome(value: collected.emitted ?? returned, output: collected.output)
    }
}
