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

    static func run(_ script: String) throws -> Outcome {
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
