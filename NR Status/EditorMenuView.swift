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

struct EditorMenuView : View {
    @FocusedBinding(\.document) var document: NRQL_EditorDocument?
    @FocusedBinding(\.query) var query: NrqlQuery?
    
    var body: some View {
        Group {
            Button("Run query...") {
                if let query {
                    print("query text: \(query.text)")
                    Task.detached { await query.getData() }
                }
                if var document {
                    print("document text: \(document.text)")
                    document.runFocusedQuery()
                }
            }.keyboardShortcut("\n")
        }
    }
}
