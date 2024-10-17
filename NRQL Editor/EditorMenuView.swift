//
//  EditorMenuView.swift
//  NR Status
//
//  Created by Eric Baur on 10/15/24.
//

import SwiftUI

struct EditorMenuView : View {
    @FocusedBinding(\.document) var document: NRQL_EditorDocument?

    var body: some View {
        Group {
            Button("Run query...") {
                if var document {
                    document.runQuery()
                }
            }.keyboardShortcut("\n")
        }
    }
}
