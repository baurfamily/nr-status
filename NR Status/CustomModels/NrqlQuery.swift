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
    
    // bumped on every successful run, so views can rebuild charts for new data
    private(set) var runCount = 0
    
    // the problem with the latest quiet run, while the previous result stays on screen
    private(set) var liveError: String?
    
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
        let defaultTitle = "NRQL Query"
        if let title = format?.title { return title }
        let withoutFormat = ChartFormat.strip(from: text)
        guard let titleString = withoutFormat.split(separator: "\n").first else { return defaultTitle }
        guard titleString.starts(with: "//") else { return defaultTitle }
        
        let title = titleString.dropFirst(2).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return defaultTitle }
        
        return title
    }
    
    init(from text: String, run: Bool = false) {
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
    /// A quiet run (used while typing) keeps showing the previous result while it
    /// runs, and keeps it if the new text turns out not to be valid yet.
    func getData(quiet: Bool = false) async {
        if !quiet { await setState(.running) }
        
        do {
            let container = try await Queries().getNrqlData(query: nrql)
            // a newer run has taken over, so don't clobber its state
            guard !Task.isCancelled else { return }
            
            await setState(container.map { .loaded($0) } ?? .failed("The query returned no data"), quiet: quiet)
        } catch {
            guard !Task.isCancelled else { return }
            
            await setState(.failed(error.localizedDescription), quiet: quiet)
        }
    }
    
    /// Starts a run without waiting, cancelling any run still in flight.
    func run(quiet: Bool = false) {
        runningTask?.cancel()
        runningTask = Task { await getData(quiet: quiet) }
    }
    
    @MainActor private func setState(_ newState: State, quiet: Bool = false) {
        switch newState {
        case .loaded:
            runCount += 1
            liveError = nil
            state = newState
        case .failed(let message) where quiet && resultContainer != nil:
            liveError = message
        default:
            liveError = nil
            state = newState
        }
    }
    
    /// Whether the text looks finished enough to be worth running while it's being typed.
    static func looksComplete(_ nrql: String) -> Bool {
        let text = nrql.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return false }
        
        let upper = text.uppercased()
        let hasFrom = upper.range(of: #"\bFROM\s+\S"#, options: .regularExpression) != nil
        let hasSelect = upper.range(of: #"\bSELECT\s+\S"#, options: .regularExpression) != nil
        guard hasFrom && hasSelect else { return false }
        
        guard text.filter({ $0 == "(" }).count == text.filter({ $0 == ")" }).count,
              text.filter({ $0 == "'" }).count % 2 == 0,
              text.filter({ $0 == "\"" }).count % 2 == 0
        else { return false }
        
        // ends in the middle of something
        let dangling = #"(,|\(|=|<|>|\+|-|\*|/|\b(SELECT|FROM|WHERE|FACET|AND|OR|NOT|AS|IN|LIKE|RLIKE|IS|BY|WITH|SINCE|UNTIL|LIMIT|OFFSET|COMPARE|SLIDE|ORDER|TIMESERIES\s+AUTO\s+BY))$"#
        return upper.range(of: dangling, options: .regularExpression) == nil
    }
    
    private func hash(nrql: String) -> String {
        SHA256.hash( data:Data(nrql.utf8) ).description
    }
    
    private func textWillUpdate(to newValue: String) {
        format = ChartFormat.parse(from: newValue)
        let lines = ChartFormat.strip(from: newValue).split(separator: "\n").filter { !$0.starts(with: "//") }
        let nrql = lines.joined(separator: "\n")
        if nrql != self.nrql {
            self.nrql = nrql
        }
    }
}
