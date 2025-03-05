//
//  NRQL_EditorApp.swift
//  NRQL Editor
//
//  Created by Eric Baur on 10/14/24.
//

import SwiftUI

struct DocumentFocusedValueKey: FocusedValueKey {
  typealias Value = Binding<NRQL_EditorDocument>
}

struct QueryFocusedValueKey: FocusedValueKey {
    typealias Value = Binding<NrqlQuery>
}

extension FocusedValues {
  var document: DocumentFocusedValueKey.Value? {
    get {
      return self[DocumentFocusedValueKey.self]
    }
            
    set {
        self[DocumentFocusedValueKey.self] = newValue
    }
  }
    
  var query: QueryFocusedValueKey.Value? {
        get {
            return self[QueryFocusedValueKey.self]
        }
        
        set {
            self[QueryFocusedValueKey.self] = newValue
        }
    }
}

@main
struct NRQL_EditorApp: App {
    @Environment(\.openWindow) var openWindow

    var body: some Scene {
        WindowGroup(id: "summary-view") { SummaryView() }
        WindowGroup(id: "sample-charts") { ChartSampleView() }
        WindowGroup(id: "nrql-viewer") {
            NrqlViewer()
        }
        .commands {
            CommandMenu("Features") {
                Button(action: {
                    openWindow(id: "summary-view")
                }, label: {
                    Text("Summary View")
                })
                Button(action: {
                    openWindow(id: "sample-charts")
                }, label: {
                    Text("Sample Charts")
                })
                Button(action: {
                    openWindow(id: "nrql-viewer")
                }, label: {
                    Text("NRQL Viewer")
                }).keyboardShortcut("n", modifiers: [ .command, .shift ])
            }
            CommandMenu("Editor") { EditorMenuView() }
        }
            
        // the NRQL viewer document stuff
        DocumentGroup(newDocument: NRQL_EditorDocument()) { file in
            DocumentView(document: file.$document)
                .focusedSceneValue(\.document, file.$document)
        }
        
        Settings {
            PreferencesView()
        }
    }
}
