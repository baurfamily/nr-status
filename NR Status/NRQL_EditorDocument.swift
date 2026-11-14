//
//  NRQL_EditorDocument.swift
//  NRQL Editor
//
//  Created by Eric Baur on 10/14/24.
//

import SwiftUI
import UniformTypeIdentifiers

extension UTType {
    static var nrMarkdown: UTType {
        UTType(exportedAs: "net.baurhome.nrmd", conformingTo: .plainText)
    }
}

/// One blank-line separated block of the document, shown as its own editor with
/// the query's results beneath it. The file text is the source of truth; cells
/// are derived from it on load and joined back together on save.
struct NrqlCell: Identifiable {
    let id = UUID()
    var isCollapsed = false
    // set on a new cell so its editor takes the keyboard once it appears
    var focusOnAppear = false

    // set at creation and by `convert`; sticky, so typing a fence doesn't change what the editor shows
    private(set) var kind: NrqlCellKind

    var text: String {
        didSet { query.text = text }
    }

    /// What the editor shows: the text, minus a code cell's fence lines.
    var editorText: String {
        get { kind.unwrap(text) }
        set { text = kind.wrap(newValue) }
    }

    // a reference type, so running it doesn't mutate the document
    let query: NrqlQuery

    init(text: String, kind: NrqlCellKind? = nil, focusOnAppear: Bool = false) {
        let kind = kind ?? NrqlCellKind.detect(in: text)
        self.text = text
        self.kind = kind
        self.focusOnAppear = focusOnAppear
        self.query = NrqlQuery(from: text, kind: kind)
    }

    /// Changes the kind of cell, keeping what's in the editor.
    mutating func convert(to newKind: NrqlCellKind) {
        guard newKind != kind else { return }
        let shown = editorText
        kind = newKind
        query.kind = newKind
        editorText = shown
    }

    // comment-only cells have nothing to run
    var isRunnable: Bool {
        guard kind == .nrql || kind == .lua || kind == .nerdgraph else { return false }
        let code = query.script ?? query.nrql
        return !code.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

struct NRQL_EditorDocument: FileDocument {
    var cells: [NrqlCell]
    var focusedCellId: NrqlCell.ID?

    // Document copies share the runs just as they share the cells' query objects.
    private final class Execution {
        @MainActor var tasks: [UUID: Task<Void, Never>] = [:]
    }
    private let execution = Execution()

    var text: String {
        NrqlDocumentParser.join(cells.map(\.text))
    }

    init(text: String = "```nrql\n// Title of query\nFROM \n```") {
        cells = Self.cells(from: text)
    }

    static var readableContentTypes: [UTType] { [.nrMarkdown] }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents,
            let string = String(data: data, encoding: .utf8)
        else {
            throw CocoaError(.fileReadCorruptFile)
        }
        cells = Self.cells(from: string)
    }

    private static func cells(from text: String) -> [NrqlCell] {
        NrqlDocumentParser.blocks(text).map { NrqlCell(text: $0) }
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        .init(regularFileWithContents: Data(text.utf8))
    }

    var focusedCell: NrqlCell? {
        cells.first { $0.id == focusedCellId }
    }

    var connection: Result<NrqlConnection, Error> {
        Result {
            let configs = cells.enumerated().filter { $0.element.kind == .config }
            guard configs.count <= 1, configs.first.map({ $0.offset == 0 }) ?? true else {
                throw NrqlConnection.ConfigurationError(message: "Place a single config fence at the top of the document.")
            }
            guard let cell = configs.first?.element else { return NrqlConnection() }
            let text = cell.query.text
            guard text.components(separatedBy: "\n").last.map(NrqlCellKind.isClosingFence) == true else {
                throw NrqlConnection.ConfigurationError(message: "Close the document config with ```.")
            }
            return try NrqlConnection.parseDocumentConfig(cell.kind.unwrap(text))
        }
    }

    /// Adds an editable, non-runnable defaults cell without changing existing queries.
    mutating func addConfiguration() {
        if let index = cells.firstIndex(where: { $0.kind == .config }) {
            cells[index].isCollapsed = false
            cells[index].focusOnAppear = true
            focusedCellId = cells[index].id
            return
        }
        let cell = NrqlCell(text: NrqlCellKind.config.template, focusOnAppear: true)
        cells.insert(cell, at: 0)
        focusedCellId = cell.id
    }

    mutating func setDefaultApiKey(_ name: String?) throws {
        var options = try connection.get()
        options.apiKeyName = name
        try updateConfiguration(options)
    }

    mutating func setDefaultAccountIds(_ ids: [Int]?) throws {
        var options = try connection.get()
        options.accountIds = ids
        try updateConfiguration(options)
    }

    private mutating func updateConfiguration(_ options: NrqlConnection) throws {
        if let index = cells.firstIndex(where: { $0.kind == .config }) {
            let existing = NrqlCellKind.config.unwrap(cells[index].query.text)
            cells[index].editorText = try options.documentConfigText(preserving: existing)
        } else if options != NrqlConnection() {
            let template = NrqlCellKind.config.unwrap(NrqlCellKind.config.template)
            let text = try options.documentConfigText(preserving: template)
            cells.insert(NrqlCell(text: NrqlCellKind.config.wrap(text)), at: 0)
        }
    }

    @discardableResult
    mutating func addCell(after id: NrqlCell.ID? = nil, kind: NrqlCellKind = .nrql) -> NrqlCell.ID {
        let cell = NrqlCell(text: kind.template, kind: kind, focusOnAppear: true)
        if let id, let index = cells.firstIndex(where: { $0.id == id }) {
            cells.insert(cell, at: index + 1)
        } else {
            cells.append(cell)
        }
        focusedCellId = cell.id
        return cell.id
    }

    @discardableResult
    mutating func addCell(before id: NrqlCell.ID, kind: NrqlCellKind = .nrql) -> NrqlCell.ID {
        let cell = NrqlCell(text: kind.template, kind: kind, focusOnAppear: true)
        cells.insert(cell, at: cells.firstIndex { $0.id == id } ?? cells.endIndex)
        focusedCellId = cell.id
        return cell.id
    }

    /// What the cell menu (and the matching main menu items) can do to a cell.
    enum CellAction: Equatable {
        case add(NrqlCellKind, above: Bool)
        case convert(NrqlCellKind)
        case moveUp, moveDown, delete
    }

    func canPerform(_ action: CellAction, on id: NrqlCell.ID) -> Bool {
        guard let index = cells.firstIndex(where: { $0.id == id }) else { return false }
        switch action {
        case .moveUp: return index > 0
        case .moveDown: return index < cells.count - 1
        case .convert(let kind): return cells[index].kind != kind
        default: return true
        }
    }

    mutating func perform(_ action: CellAction, on id: NrqlCell.ID) {
        guard canPerform(action, on: id), let index = cells.firstIndex(where: { $0.id == id }) else { return }
        switch action {
        case .add(let kind, let above):
            if above { addCell(before: id, kind: kind) } else { addCell(after: id, kind: kind) }
        case .moveUp: cells.swapAt(index, index - 1)
        case .moveDown: cells.swapAt(index, index + 1)
        case .convert(let kind): cells[index].convert(to: kind)
        case .delete: removeCell(id)
        }
    }

    mutating func removeCell(_ id: NrqlCell.ID) {
        cells.removeAll { $0.id == id }
        if focusedCellId == id { focusedCellId = nil }
    }

    /// Named results of cells that have run, for `{{ }}` expressions to read.
    var priorResults: [LuaRuntime.PriorResult] { Self.priorResults(in: cells) }

    private static func priorResults(in cells: [NrqlCell]) -> [LuaRuntime.PriorResult] {
        cells.compactMap { cell in
            guard let name = cell.query.name else { return nil }
            if let value = cell.query.jsonResult {
                return LuaRuntime.PriorResult(name: name, value: value.luaValue)
            }
            guard let container = cell.query.resultContainer else { return nil }
            return LuaRuntime.PriorResult(name: name, value: LuaResultBridge.luaValue(from: container))
        }
    }

    /// Hides or shows code and document config; Markdown cells have nothing to collapse.
    mutating func setAllCollapsed(_ collapsed: Bool) {
        for index in cells.indices where cells[index].kind != .markdown {
            cells[index].isCollapsed = collapsed
        }
    }

    /// What a Lua expression in the given cell can read from the other cells.
    func completionScope(excluding id: NrqlCell.ID) -> LuaCompletion.Scope {
        let others = cells.filter { $0.id != id && $0.kind != .markdown }
        return LuaCompletion.Scope(
            names: others.compactMap(\.query.name),
            results: Self.priorResults(in: others)
        )
    }

    /// Runs every query, each after the ones it reads.
    @discardableResult
    @MainActor func runAllQueries() -> Task<Void, Never> {
        let all = cells
        let roots = all.filter { $0.isRunnable && !$0.query.isRunning }
        return run(NrqlDependencies.plan(for: roots, in: all, includeFinished: true), in: all)
    }

    @MainActor func clearResults() {
        for task in execution.tasks.values { task.cancel() }
        execution.tasks.removeAll()
        for cell in cells { cell.query.clearResults() }
    }

    @MainActor func runFocusedQuery() {
        guard let id = focusedCellId else { return }
        runCell(id)
    }

    /// Runs a cell, first refreshing any missing or stale results it reads.
    @MainActor func runCell(_ id: NrqlCell.ID) {
        guard let cell = cells.first(where: { $0.id == id }), cell.isRunnable else { return }
        do {
            let stale = try staleCellIds(profiles: NerdgraphProfiles.shared.load())
            run(NrqlDependencies.plan(for: [cell], in: cells, includeFinished: false, stale: stale), in: cells)
        } catch {
            cell.query.setState(.failed(error.localizedDescription))
        }
    }

    /// Results from a different connection, plus their transitive readers.
    func staleCellIds(profiles: NerdgraphProfiles.Settings) -> Set<NrqlCell.ID> {
        var invalidated = Set<NrqlCell.ID>()
        for cell in cells {
            guard cell.kind == .nrql || cell.kind == .nerdgraph, let loaded = cell.query.loadedConnection else { continue }
            do {
                let metadata = cell.kind == .nerdgraph ? NerdgraphCellSource(stored: cell.query.text).metadata
                    : NrqlConnection.metadataBody(in: cell.kind.unwrap(cell.query.text))
                let current = try NrqlConnection.parse(metadata)
                    .inheriting(connection.get())
                    .snapshot(profiles: profiles, requiresAccounts: cell.kind != .nerdgraph)
                if current != loaded { invalidated.insert(cell.id) }
            } catch {
                // Invalid routing cannot reproduce a cached result; running the cell reports the error.
                invalidated.insert(cell.id)
            }
        }
        return NrqlDependencies.staleCells(in: cells, invalidated: invalidated)
    }

    /// Cells that read a result from further down the document.
    var readingBelowCellIds: Set<NrqlCell.ID> { NrqlDependencies.cellsReadingBelow(in: cells) }

    /// The cells that running this one would run first.
    func pendingDependencies(for id: NrqlCell.ID, stale: Set<NrqlCell.ID>) -> [NrqlCell] {
        guard let cell = cells.first(where: { $0.id == id }) else { return [] }
        return NrqlDependencies.plan(
            for: [cell], in: cells, includeFinished: false, stale: stale
        ).filter { $0.id != id }
    }

    @discardableResult
    @MainActor private func run(_ order: [NrqlCell], in all: [NrqlCell]) -> Task<Void, Never> {
        let connection = connection
        let execution = execution
        let id = UUID()
        let task = Task {
            defer { execution.tasks[id] = nil }
            for cell in order {
                guard !Task.isCancelled else { return }
                do {
                    let defaults = cell.kind == .lua ? NrqlConnection() : try connection.get()
                    await cell.query.getData(results: Self.priorResults(in: all), defaults: defaults)
                } catch {
                    guard !Task.isCancelled else { return }
                    cell.query.setState(.failed(error.localizedDescription))
                }
            }
        }
        execution.tasks[id] = task
        return task
    }
}
