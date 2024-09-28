//
//  ContentView.swift
//  NR Status
//
//  Created by Eric Baur on 9/21/24.
//

import SwiftUI

struct ContentView: View {
    enum ViewSelection : String, CaseIterable {
        case List, Grid
    }
    
    @State var viewSelection: ViewSelection = .List
    
    var body: some View {
        TabView {
            Tab("Applications", systemImage: "tray.and.arrow.down.fill") {
                Picker("View Style", selection: $viewSelection) {
                    ForEach(ViewSelection.allCases, id: \.self) {
                        Text($0.rawValue)
                    }
                }.pickerStyle(.segmented)
                
                switch viewSelection {
                case .List: ApplicationView()
                case .Grid: ApplicationGridView()
                }
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
