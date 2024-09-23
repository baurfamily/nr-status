//
//  NR_StatusApp.swift
//  NR Status
//
//  Created by Eric Baur on 9/21/24.
//

import SwiftUI

@main
struct NR_StatusApp: App {
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
        }
        
        Settings {
            PreferencesView()
        }
    }
}
