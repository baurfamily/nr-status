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
    private(set) var loadedDocumentConfig: NrqlConnection?
    private(set) var loadedBindings: [LuaRuntime.PriorResult]?
    
    // the query as last sent, with `{{ }}` expressions replaced; nil before a run
    private(set) var executedNrql: String?
    private(set) var executedVariables: String?
    
    // how later cells refer to this result: `results.<name>`
    var name: String? { format?.name }
    var resultNames: [String] {
        kind == .nerdgraph ? NerdgraphCellSource(stored: text).bindingNames : name.map { [$0] } ?? []
    }

    var namedResults: [LuaRuntime.PriorResult] {
        if let value = jsonResult {
            if let loadedBindings { return loadedBindings }
            let bindings = (try? NerdgraphCellSource(stored: text).resultBindings()) ?? []
            return bindings.filter { $0.expression == nil }.map { .init(name: $0.name, value: value.luaValue) }
        }
        guard let name, let container = resultContainer else { return [] }
        return [.init(name: name, value: LuaResultBridge.luaValue(from: container))]
    }
    
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

    var expressionCode: String {
        if let script { return script }
        let source = kind == .nerdgraph ? variables : kind == .markdown ? text : nrql
        let expressions = NrqlInterpolation.expressions(in: source)
        let bindings = kind == .nerdgraph ? NerdgraphCellSource(stored: text).bindingExpressions : []
        return (expressions + bindings).joined(separator: "\n")
    }

    var readsDocumentConfig: Bool { LuaRuntime.referencesConfiguration(in: expressionCode) }
    
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
    /// `defaults` supplies document settings for routing and the Lua `config` global.
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
        loadedBindings = nil
        
        do {
            let consumesConfig = readsDocumentConfig
            let documentConfig = script != nil || consumesConfig
                ? try defaults.effectiveConfiguration(profiles: profiles.load()) : NrqlConnection()
            let configSnapshot = consumesConfig ? documentConfig : nil
            if let script {
                let outcome = await Self.runScript(script, results: results, config: documentConfig)
                guard !Task.isCancelled, executionID == id else { return }
                setState(outcome, documentConfig: configSnapshot)
                return
            }
            if let graphQL {
                let bindings = try graphQL.resultBindings()
                guard graphQL.isClosed else {
                    throw NrqlConnection.ConfigurationError(message: "Close the GraphQL and variables fences with ```.")
                }
                let variables = try await Task.detached {
                    try NrqlInterpolation.expandJSON(graphQL.variables, results: results, config: documentConfig)
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
                let exported = try await Task.detached {
                    try bindings.map { binding -> LuaRuntime.PriorResult in
                        guard let expression = binding.expression else {
                            return .init(name: binding.name, value: value.luaValue)
                        }
                        do {
                            let extracted = try LuaRuntime.run(
                                "return (\(expression))", results: results, config: documentConfig, response: value
                            ).value
                            if case .nil = extracted {
                                throw NrqlConnection.ConfigurationError(message: "The expression has no value.")
                            }
                            _ = try JSONValue(luaValue: extracted)
                            return .init(name: binding.name, value: extracted)
                        } catch {
                            throw NrqlConnection.ConfigurationError(message: "Nerdgraph variable '\(binding.name)': \(error.localizedDescription)")
                        }
                    }
                }.value
                guard !Task.isCancelled, executionID == id else { return }
                setState(.jsonLoaded(value), connection: snapshot, documentConfig: configSnapshot, bindings: exported)
                return
            }
            let sent = try await Task.detached {
                try NrqlInterpolation.expand(nrql, results: results, config: documentConfig)
            }.value
            guard !Task.isCancelled, executionID == id else { return }
            let connection = try options.get().inheriting(defaults)
            let snapshot = try connection.snapshot(profiles: profiles.load())
            let config = try connection.resolve(profiles: profiles)
            setExecuted(sent)
            let container = try await Queries(config: config, session: session).getNrqlData(query: sent)
            // a newer run has taken over, so don't clobber its state
            guard !Task.isCancelled, executionID == id else { return }
            
            setState(container.map { .loaded($0) } ?? .failed("The query returned no data"),
                     connection: snapshot, documentConfig: configSnapshot)
        } catch {
            guard !Task.isCancelled, executionID == id else { return }
            
            setState(.failed(error.localizedDescription))
        }
    }
    
    /// Runs Lua off the main actor; the script's `emit` or `return` value becomes this cell's result.
    private static func runScript(
        _ script: String, results: [LuaRuntime.PriorResult], config: NrqlConnection
    ) async -> State {
        await Task.detached {
            do {
                let outcome = try LuaRuntime.run(script, results: results, config: config)
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
        loadedDocumentConfig = nil
        loadedBindings = nil
        setExecuted(nil)
    }
    
    @MainActor func setState(
        _ newState: State, connection: NrqlConnection.Snapshot? = nil, documentConfig: NrqlConnection? = nil,
        bindings: [LuaRuntime.PriorResult]? = nil
    ) {
        switch newState {
        case .loaded, .jsonLoaded:
            loadedAt = Date()
            loadedConnection = connection
            loadedDocumentConfig = documentConfig
            loadedBindings = bindings
        default: loadedBindings = nil
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
