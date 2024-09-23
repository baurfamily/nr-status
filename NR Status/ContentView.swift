//
//  ContentView.swift
//  NR Status
//
//  Created by Eric Baur on 9/21/24.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            Tab("Applications", systemImage: "tray.and.arrow.down.fill") {
                ApplicationView()
            }
            .badge(2)

            Tab("Synthetics", systemImage: "tray.and.arrow.up.fill") {
                SyntheticsView()
            }

            Tab("Service Levels", systemImage: "person.crop.circle.fill") {
                Text("Third Page")
            }
            .badge("!")
        }
    }
    
}

#Preview {
    ContentView()
}
