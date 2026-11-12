//
//  LuaRuntimeTests.swift
//  NR StatusTests
//

import Testing
import Foundation
import LuaSwift
@testable import NR_Status

struct LuaRuntimeTests {
    @Test func returnsValue() throws {
        let outcome = try LuaRuntime.run("return 1 + 1")
        #expect(outcome.value.numberValue == 2)
    }

    @Test func emitOverridesReturn() throws {
        let outcome = try LuaRuntime.run("emit({ a = 1 }); return 5")
        #expect(outcome.value.tableValue?["a"]?.intValue == 1)
    }

    @Test func capturesPrint() throws {
        let outcome = try LuaRuntime.run("print('a', 1); return nil")
        #expect(outcome.output == ["a\t1"])
    }

    @Test func sandboxRemovesIOAndLoad() throws {
        #expect(try LuaRuntime.run("return io == nil").value.boolValue == true)
        #expect(try LuaRuntime.run("return load == nil").value.boolValue == true)
        #expect(try LuaRuntime.run("return os.execute == nil").value.boolValue == true)
    }

    @Test func stopsRunawayLoops() {
        #expect(throws: LuaError.self) { try LuaRuntime.run("while true do end") }
    }

    @Test func limitsMemory() {
        #expect(throws: LuaError.self) {
            try LuaRuntime.run("local t = {} for i = 1, 1e9 do t[i] = {i} end return #t")
        }
    }

    @Test func reportsSyntaxErrors() {
        #expect(throws: LuaError.self) { try LuaRuntime.run("not valid lua") }
    }
}
