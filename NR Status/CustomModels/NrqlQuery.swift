//
//  NrqlQuery.swift
//  NR Status
//
//  Created by Eric Baur on 10/14/24.
//

import Foundation
import CodeEditorView
import CryptoKit
import LanguageSupport

@Observable class NrqlQuery : Identifiable, Equatable {
    enum State {
        case idle
        case running
        case loaded(NrdbResultContainer)
        case failed(String)
    }
    
    // this is the full text, including comments
    var text: String = "" {
        willSet { textWillUpdate(to: newValue) }
    }
    
    // this is just the functional part, minus comments
    private(set) var nrql: String
    
    // the Lua code if this is a script cell; nil otherwise
    private(set) var script: String?
    
    // set by the cell that owns this, since the fence isn't visible to say which it is; a lone
    // query's kind comes from the text, and text without a fence is NRQL
    var kind: NrqlCellKind
    
    var isScript: Bool { kind == .lua }

    // chart settings from a doc-comment, if the text has one
    private(set) var format: ChartFormat?
    
    static func == (lhs: NrqlQuery, rhs: NrqlQuery) -> Bool {
        lhs.text == rhs.text
    }
    
    // so we can be embeded in a code editor, we need a position and messages... I guess?
    // not sure if I really need these, or if they need/should be here.
    var position: CodeEditor.Position
    var messages: Set<TextLocated<Message>> = Set()
    
    // Views switch on this, so a new result replaces the "running" content and
    // charts that copy their data at creation get rebuilt with the new results.
    // Always change it through setState(_:) so updates happen on the main actor.
    private(set) var state: State = .idle
    
    // when the current result arrived; cells reading this one compare against it
    private(set) var loadedAt: Date?
    
    // the query as last sent, with `{{ }}` expressions replaced; nil before a run
    private(set) var executedNrql: String?
    
    // how later cells refer to this result: `results.<name>`
    var name: String? { format?.name }
    
    @ObservationIgnored private var runningTask: Task<Void, Never>?
    
    var isRunning: Bool {
        if case .running = state { return true }
        return false
    }
    
    // the data from the last successful run; nil while a new run is in flight
    var resultContainer: NrdbResultContainer? {
        if case .loaded(let container) = state { return container }
        return nil
    }
    
    var errorMessage: String? {
        if case .failed(let message) = state { return message }
        return nil
    }
    
    var id: String { hash(nrql: self.nrql) }
    
    var title: String {
        if kind == .markdown {
            let heading = text.split(separator: "\n").first { $0.hasPrefix("#") }
            return heading.map { $0.drop { $0 == "#" }.trimmingCharacters(in: .whitespaces) } ?? "Markdown"
        }
        let defaultTitle = isScript ? "Lua Script" : "NRQL Query"
        if let title = format?.title { return title }
        if let script {
            let first = script.split(separator: "\n").first { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
            guard let first, first.trimmingCharacters(in: .whitespaces).hasPrefix("--") else { return defaultTitle }
            let title = first.drop { $0 == " " || $0 == "-" }.trimmingCharacters(in: .whitespaces)
            return title.isEmpty ? defaultTitle : title
        }
        let withoutFormat = ChartFormat.strip(from: kind.unwrap(text))
        guard let titleString = withoutFormat.split(separator: "\n").first else { return defaultTitle }
        guard titleString.starts(with: "//") else { return defaultTitle }
        
        let title = titleString.dropFirst(2).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return defaultTitle }
        
        return title
    }
    
    init(from text: String, kind: NrqlCellKind? = nil, run: Bool = false) {
        let detected = NrqlCellKind.detect(in: text)
        self.kind = kind ?? (detected == .markdown ? .nrql : detected)
        self.nrql = ""
        self.text = text
        self.position = .init(selections: [NSMakeRange(0, 0)], verticalScrollPosition: 0)
        self.messages = Set<TextLocated<Message>>()
        
        textWillUpdate(to: text)
        
        if run {
            self.run()
        }
    }
    
    /// Runs the query and waits for the result; see `state` for the outcome.
    /// `results` are the earlier cell results that `{{ }}` expressions can read.
    func getData(results: [LuaRuntime.PriorResult] = []) async {
        await setState(.running)
        
        if let script {
            await setExecuted(nil)
            await setState(await Self.runScript(script, results: results))
            return
        }
        
        let sent: String
        do {
            sent = try NrqlInterpolation.expand(nrql, results: results)
        } catch {
            await setExecuted(nil)
            await setState(.failed(error.localizedDescription))
            return
        }
        await setExecuted(sent)
        
        do {
            let container = try await Queries().getNrqlData(query: sent)
            // a newer run has taken over, so don't clobber its state
            guard !Task.isCancelled else { return }
            
            await setState(container.map { .loaded($0) } ?? .failed("The query returned no data"))
        } catch {
            guard !Task.isCancelled else { return }
            
            await setState(.failed(error.localizedDescription))
        }
    }
    
    /// Runs Lua off the main actor; the script's `emit` or `return` value becomes this cell's result.
    private static func runScript(_ script: String, results: [LuaRuntime.PriorResult]) async -> State {
        await Task.detached {
            do {
                let outcome = try LuaRuntime.run(script, results: results)
                return State.loaded(try LuaResultBridge.container(from: outcome.value))
            } catch {
                return State.failed(error.localizedDescription)
            }
        }.value
    }
    
    /// Starts a run without waiting, cancelling any run still in flight.
    func run(results: [LuaRuntime.PriorResult] = []) {
        runningTask?.cancel()
        runningTask = Task { await getData(results: results) }
    }
    
    @MainActor func setState(_ newState: State) {
        if case .loaded = newState { loadedAt = Date() }
        state = newState
    }
    
    @MainActor private func setExecuted(_ nrql: String?) {
        executedNrql = nrql
    }
    
    private func hash(nrql: String) -> String {
        SHA256.hash( data:Data(nrql.utf8) ).description
    }
    
    private func textWillUpdate(to newValue: String) {
        guard kind != .markdown else {
            format = nil
            script = nil
            nrql = ""
            return
        }
        let code = kind.unwrap(newValue)
        format = ChartFormat.parse(from: code)
        let body = ChartFormat.strip(from: code)
        if kind == .lua {
            script = body
            nrql = ""
            return
        }
        script = nil
        let lines = body.split(separator: "\n").filter { !$0.starts(with: "//") }
        let nrql = lines.joined(separator: "\n")
        if nrql != self.nrql {
            self.nrql = nrql
        }
    }
}
