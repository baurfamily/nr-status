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
    
    var body: some Scene {
        DocumentGroup(newDocument: NRQL_EditorDocument()) { file in
            ContentView(document: file.$document).focusedSceneValue(\.document, file.$document)
        }.commands {
            CommandMenu("Editor") {
                EditorMenuView()
            }
        }
        
        Settings {
            PreferencesView()
        }
    }
}
