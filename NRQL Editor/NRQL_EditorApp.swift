//
//  NRQL_EditorApp.swift
//  NRQL Editor
//
//  Created by Eric Baur on 10/14/24.
//

import SwiftUI

@main
struct NRQL_EditorApp: App {
    var body: some Scene {
        DocumentGroup(newDocument: NRQL_EditorDocument()) { file in
            ContentView(document: file.$document)
        }
    }
}
