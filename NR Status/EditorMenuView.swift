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
        }
    }
}
