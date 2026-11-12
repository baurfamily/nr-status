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

    static func run(_ script: String, results: [PriorResult] = []) throws -> Outcome {
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
        engine.registerFunction(name: "__results") { _ in resultsTable }
        try engine.run(resultsPrelude)

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
