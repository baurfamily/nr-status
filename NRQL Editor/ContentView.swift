//
//  ContentView.swift
//  NRQL Editor
//
//  Created by Eric Baur on 10/14/24.
//

import SwiftUI

struct ContentView: View {
    @Binding var document: NRQL_EditorDocument

    var body: some View {
        NavigationSplitView {
            List {
                Text("one")
                Text("two")
                Text("three")
            }
        } content: {
            TextEditor(text: $document.text)
        } detail: {
            List {
                Image(systemName: "checkmark")
                Image(systemName: "house")
            }
        }
        
        
    }
}

#Preview {
    ContentView(document: .constant(NRQL_EditorDocument()))
}
