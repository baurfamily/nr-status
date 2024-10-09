//
//  NR_StatusApp.swift
//  NR Status
//
//  Created by Eric Baur on 9/21/24.
//

import SwiftUI

@main
struct NR_StatusApp: App {
    @Environment(\.openWindow) var openWindow
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .commands {
            CommandMenu("Custom Menu") {
                Button(action: {
                    print("Menu Button selected")
                }, label: {
                    Text("Menu Button")
                })
            }
            CommandMenu("NRQL") {
                Button(action: {
                    openWindow(id: "NRQLEditor")
                }, label: {
                    Text("Open NRQL Editor")
                })
            }
        }
        
        WindowGroup("NRQLEditor", id: "NRQLEditor") {
            NRQLEditorView()
        }
        
        Settings {
            PreferencesView()
        }
    }
}
