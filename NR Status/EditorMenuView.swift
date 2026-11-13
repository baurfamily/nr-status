//
//  EditorMenuView.swift
//  NR Status
//
//  Created by Eric Baur on 10/15/24.
//

import SwiftUI

//here for testing
import CodeEditorView
import LanguageSupport

struct ExportMenuView: View {
    @FocusedBinding(\.document) var document: NRQL_EditorDocument?

    var body: some View {
        Menu("Export") {
            ForEach(NrqlExport.Format.allCases, id: \.self) { format in
                Button(format.title) {
                    if let document { NrqlExport.save(format, document: document) }
                }
            }
        }
        .disabled(document == nil)
    }
}

struct EditorMenuView : View {
    @FocusedBinding(\.document) var document: NRQL_EditorDocument?
    @FocusedBinding(\.query) var query: NrqlQuery?
    
    var body: some View {
        Group {
            Button("Run query...") {
                if let query {
                    query.run()
                }
                document?.runFocusedQuery()
            }.keyboardShortcut("\n")
            Button("Run all queries") {
                document?.runAllQueries()
            }.keyboardShortcut("\n", modifiers: [.command, .shift])

            Divider()
            Menu("Add Cell Above") {
                ForEach(NrqlCellKind.allCases) { cellButton($0.title, .add($0, above: true)) }
            }
            Menu("Add Cell Below") {
                ForEach(NrqlCellKind.allCases) { cellButton($0.title, .add($0, above: false)) }
            }
            Divider()
            cellButton("Move Cell Up", .moveUp)
            cellButton("Move Cell Down", .moveDown)
            Divider()
            Menu("Convert Cell To") {
                ForEach(NrqlCellKind.allCases) { cellButton($0.title, .convert($0)) }
            }
            Divider()
            cellButton("Delete Cell", .delete)
        }
    }

    // acts on the cell with focus, like the cell's own menu
    private func cellButton(_ title: String, _ action: NRQL_EditorDocument.CellAction) -> some View {
        Button(title) {
            if let id = document?.focusedCellId { document?.perform(action, on: id) }
        }
        .disabled(document?.focusedCellId.map { document?.canPerform(action, on: $0) ?? false } != true)
    }
}
