//
//  NRQL_EditorDocument.swift
//  NRQL Editor
//
//  Created by Eric Baur on 10/14/24.
//

import SwiftUI
import UniformTypeIdentifiers

extension UTType {
    static var nrql: UTType {
        UTType(exportedAs: "net.baurhome.nrql")
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

    var text: String {
        didSet { query.text = text }
    }

    // a reference type, so running it doesn't mutate the document
    let query: NrqlQuery

    init(text: String, focusOnAppear: Bool = false) {
        self.text = text
        self.focusOnAppear = focusOnAppear
        self.query = NrqlQuery(from: text)
    }

    // comment-only cells have nothing to run
    var isRunnable: Bool {
        let code = query.script ?? query.nrql
        return !code.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

struct NRQL_EditorDocument: FileDocument {
    var cells: [NrqlCell]
    var focusedCellId: NrqlCell.ID?

    var text: String {
        NrqlDocumentParser.join(cells.map(\.text))
    }

    init(text: String = "// Title of query\nFROM ") {
        cells = Self.cells(from: text)
    }

    static var readableContentTypes: [UTType] { [.nrql] }

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

    static let scriptTemplate = "```lua\n\n```"

    @discardableResult
    mutating func addCell(after id: NrqlCell.ID? = nil, script: Bool = false) -> NrqlCell.ID {
        let cell = NrqlCell(text: script ? Self.scriptTemplate : "FROM ", focusOnAppear: true)
        if let id, let index = cells.firstIndex(where: { $0.id == id }) {
            cells.insert(cell, at: index + 1)
        } else {
            cells.append(cell)
        }
        focusedCellId = cell.id
        return cell.id
    }

    @discardableResult
    mutating func addCell(before id: NrqlCell.ID, script: Bool = false) -> NrqlCell.ID {
        let cell = NrqlCell(text: script ? Self.scriptTemplate : "FROM ", focusOnAppear: true)
        cells.insert(cell, at: cells.firstIndex { $0.id == id } ?? cells.endIndex)
        focusedCellId = cell.id
        return cell.id
    }

    /// What the cell menu (and the matching main menu items) can do to a cell.
    enum CellAction: CaseIterable {
        case addQueryAbove, addQueryBelow, addScriptAbove, addScriptBelow, moveUp, moveDown, delete
    }

    func canPerform(_ action: CellAction, on id: NrqlCell.ID) -> Bool {
        guard let index = cells.firstIndex(where: { $0.id == id }) else { return false }
        switch action {
        case .moveUp: return index > 0
        case .moveDown: return index < cells.count - 1
        default: return true
        }
    }

    mutating func perform(_ action: CellAction, on id: NrqlCell.ID) {
        guard canPerform(action, on: id), let index = cells.firstIndex(where: { $0.id == id }) else { return }
        switch action {
        case .addQueryAbove: addCell(before: id)
        case .addQueryBelow: addCell(after: id)
        case .addScriptAbove: addCell(before: id, script: true)
        case .addScriptBelow: addCell(after: id, script: true)
        case .moveUp: cells.swapAt(index, index - 1)
        case .moveDown: cells.swapAt(index, index + 1)
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
            guard let name = cell.query.name, let container = cell.query.resultContainer else { return nil }
            return LuaRuntime.PriorResult(name: name, value: LuaResultBridge.luaValue(from: container))
        }
    }

    /// Runs every query, each after the ones it reads.
    func runAllQueries() {
        let all = cells
        let roots = all.filter { $0.isRunnable && !$0.query.isRunning }
        run(NrqlDependencies.plan(for: roots, in: all, includeFinished: true), in: all)
    }

    func runFocusedQuery() {
        guard let id = focusedCellId else { return }
        runCell(id)
    }

    /// Runs a cell, first running any cell it reads that has no result yet.
    func runCell(_ id: NrqlCell.ID) {
        guard let cell = cells.first(where: { $0.id == id }), cell.isRunnable else { return }
        run(NrqlDependencies.plan(for: [cell], in: cells, includeFinished: false), in: cells)
    }

    /// Cells showing a result that a cell they read has since replaced.
    var staleCellIds: Set<NrqlCell.ID> { NrqlDependencies.staleCells(in: cells) }

    /// Cells that read a result from further down the document.
    var readingBelowCellIds: Set<NrqlCell.ID> { NrqlDependencies.cellsReadingBelow(in: cells) }

    /// The cells that running this one would run first.
    func pendingDependencies(for id: NrqlCell.ID) -> [NrqlCell] {
        guard let cell = cells.first(where: { $0.id == id }) else { return [] }
        return NrqlDependencies.plan(for: [cell], in: cells, includeFinished: false).filter { $0.id != id }
    }

    private func run(_ order: [NrqlCell], in all: [NrqlCell]) {
        Task {
            for cell in order {
                await cell.query.getData(results: Self.priorResults(in: all))
            }
        }
    }
}
