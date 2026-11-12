//
//  NrqlEditorWindow.swift
//  NR Status
//
//  Created by Eric Baur on 2/20/25.
//

import SwiftUI

/// A scratch notebook window (not backed by a file); use File > New for a saved document.
struct NrqlEditorWindow : View {
    @State private var document = NRQL_EditorDocument(
        text: "// Transactions by name\nSELECT count(*) FROM Transaction FACET name SINCE 1 day ago"
    )

    var body: some View {
        DocumentView(document: $document)
            .frame(minWidth: 500, minHeight: 400)
            .focusedSceneValue(\.document, $document)
    }
}

#Preview {
    NrqlEditorWindow()
}
