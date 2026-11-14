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
        case jsonLoaded(JSONValue)
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

    private(set) var loadedConnection: NrqlConnection.Snapshot?
    
    // the query as last sent, with `{{ }}` expressions replaced; nil before a run
    private(set) var executedNrql: String?
    private(set) var executedVariables: String?
    
    // how later cells refer to this result: `results.<name>`
    var name: String? { format?.name }
    
    @ObservationIgnored private var runningTask: Task<Void, Never>?
    @ObservationIgnored private var executionID = UUID()
    
    var isRunning: Bool {
        if case .running = state { return true }
        return false
    }
    
    // the data from the last successful run; nil while a new run is in flight
    var resultContainer: NrdbResultContainer? {
        if case .loaded(let container) = state { return container }
        return nil
    }

    var jsonResult: JSONValue? {
        if case .jsonLoaded(let value) = state { return value }
        return nil
    }

    var hasResult: Bool { resultContainer != nil || jsonResult != nil }

    var variables: String {
        kind == .nerdgraph ? NerdgraphCellSource(stored: text).variables : ""
    }
    
    var errorMessage: String? {
        if case .failed(let message) = state { return message }
        return nil
    }
    
    var id: String { hash(nrql: self.nrql) }
    
    var title: String {
        if kind == .config { return "Document Config" }
        if kind == .markdown {
            let heading = text.split(separator: "\n").first { $0.hasPrefix("#") }
            return heading.map { $0.drop { $0 == "#" }.trimmingCharacters(in: .whitespaces) } ?? "Markdown"
        }
        let defaultTitle = kind == .nerdgraph ? "Nerdgraph Query" : isScript ? "Lua Script" : "NRQL Query"
        if let title = format?.title { return title }
        if let script {
            let first = script.split(separator: "\n").first { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
            guard let first, first.trimmingCharacters(in: .whitespaces).hasPrefix("--") else { return defaultTitle }
            let title = first.drop { $0 == " " || $0 == "-" }.trimmingCharacters(in: .whitespaces)
            return title.isEmpty ? defaultTitle : title
        }
        guard format == nil else { return defaultTitle }
        guard let titleString = kind.unwrap(text).split(separator: "\n").first else { return defaultTitle }
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
    @MainActor func getData(
        results: [LuaRuntime.PriorResult] = [], defaults: NrqlConnection = NrqlConnection(),
        profiles: NerdgraphProfiles = .shared, session: URLSession = .shared
    ) async {
        guard !Task.isCancelled else { return }
        let id = UUID()
        executionID = id
        let script = script
        let nrql = nrql
        let graphQL = kind == .nerdgraph ? NerdgraphCellSource(stored: text) : nil
        let options = Result {
            try NrqlConnection.parse(graphQL?.metadata ?? NrqlConnection.metadataBody(in: kind.unwrap(text)))
        }
        setState(.running)
        setExecuted(nil)
        
        if let script {
            let outcome = await Self.runScript(script, results: results)
            guard !Task.isCancelled, executionID == id else { return }
            setState(outcome)
            return
        }
        
        do {
            if let graphQL {
                guard graphQL.isClosed else {
                    throw NrqlConnection.ConfigurationError(message: "Close the GraphQL and variables fences with ```.")
                }
                let variables = try await Task.detached {
                    try NrqlInterpolation.expandJSON(graphQL.variables, results: results)
                }.value
                guard !Task.isCancelled, executionID == id else { return }
                let connection = try options.get().inheriting(defaults)
                let snapshot = try connection.snapshot(profiles: profiles.load(), requiresAccounts: false)
                let config = try connection.resolve(profiles: profiles, requiresAccounts: false)
                setExecuted(graphQL.operation, variables: try variables.encodedText(pretty: true))
                let value: JSONValue = try await NerdgraphClient(config: config, session: session).sendResponse(
                    graphQL.operation, variables: variables
                )
                guard !Task.isCancelled, executionID == id else { return }
                guard case .object = value else {
                    throw NrqlConnection.ConfigurationError(message: "Nerdgraph returned an invalid response: expected a JSON object.")
                }
                setState(.jsonLoaded(value), connection: snapshot)
                return
            }
            let sent = try await Task.detached {
                try NrqlInterpolation.expand(nrql, results: results)
            }.value
            guard !Task.isCancelled, executionID == id else { return }
            let connection = try options.get().inheriting(defaults)
            let snapshot = try connection.snapshot(profiles: profiles.load())
            let config = try connection.resolve(profiles: profiles)
            setExecuted(sent)
            let container = try await Queries(config: config, session: session).getNrqlData(query: sent)
            // a newer run has taken over, so don't clobber its state
            guard !Task.isCancelled, executionID == id else { return }
            
            setState(container.map { .loaded($0) } ?? .failed("The query returned no data"), connection: snapshot)
        } catch {
            guard !Task.isCancelled, executionID == id else { return }
            
            setState(.failed(error.localizedDescription))
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

    @MainActor func clearResults() {
        runningTask?.cancel()
        runningTask = nil
        executionID = UUID()
        setState(.idle)
        loadedAt = nil
        loadedConnection = nil
        setExecuted(nil)
    }
    
    @MainActor func setState(_ newState: State, connection: NrqlConnection.Snapshot? = nil) {
        switch newState {
        case .loaded, .jsonLoaded:
            loadedAt = Date()
            loadedConnection = connection
        default: break
        }
        state = newState
    }
    
    @MainActor private func setExecuted(_ nrql: String?, variables: String? = nil) {
        executedNrql = nrql
        executedVariables = variables
    }
    
    private func hash(nrql: String) -> String {
        SHA256.hash( data:Data(nrql.utf8) ).description
    }
    
    private func textWillUpdate(to newValue: String) {
        if kind == .nerdgraph {
            let source = NerdgraphCellSource(stored: newValue)
            format = source.format
            script = nil
            nrql = source.operation
            return
        }
        guard kind == .nrql || kind == .lua else {
            format = nil
            script = nil
            nrql = ""
            return
        }
        let code = kind.unwrap(newValue)
        format = ChartFormat.parse(from: code, lua: kind == .lua)
        let body = ChartFormat.strip(from: code, lua: kind == .lua)
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
