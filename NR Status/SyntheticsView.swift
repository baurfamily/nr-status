//
//  SyntheticsView.swift
//  NR Status
//
//  Created by Eric Baur on 9/21/24.
//

import SwiftUI

struct SyntheticsView: View {
    @State var monitors: [Entity] = []
    
    var body: some View {
        List(monitors, id: \.guid) { m in
            Text(m.name ?? "Unknown")
        }
        .padding()
        .task {
            if let monitors = try? await Queries().entities(domain: .SYNTH) {
                self.monitors = monitors
            }
        }
    }
        
}

#Preview {
    SyntheticsView()
}
