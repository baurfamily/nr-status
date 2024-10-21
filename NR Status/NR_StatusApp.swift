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
    
extension FocusedValues {
  var document: DocumentFocusedValueKey.Value? {
    get {
      return self[DocumentFocusedValueKey.self]
    }
            
    set {
        self[DocumentFocusedValueKey.self] = newValue
    }
  }
}

@main
struct NRQL_EditorApp: App {
    @Environment(\.openWindow) var openWindow
    
    var body: some Scene {
        WindowGroup(id: "summary-view") { SummaryView() }
        .commands {
            CommandMenu("Features") {
                Button(action: {
                    openWindow(id: "summary-view")
                }, label: {
                    Text("Summary View")
                })
            }
        }
        WindowGroup(id: "sample-charts") { ChartSampleView() }
        .commands {
            CommandMenu("Features") {
                Button(action: {
                    openWindow(id: "sample-charts")
                }, label: {
                    Text("Sample Charts")
                })
            }
        }
        
        // the NRQL viewer document stuff
        DocumentGroup(newDocument: NRQL_EditorDocument()) { file in
            DocumentView(document: file.$document).focusedSceneValue(\.document, file.$document)
        }.commands {
            CommandMenu("Editor") { EditorMenuView() }
        }
        
        Settings {
            PreferencesView()
        }
    }
}
