//
//  ApplicationView.swift
//  NR Status
//
//  Created by Eric Baur on 9/21/24.
//

import SwiftUI

struct ApplicationView: View {
    @State var applications: [Entity] = []
    
    var body: some View {
        List(applications, id: \.guid) { app in
            Text(app.name ?? "Unknown")
        }
        .padding()
        .task {
            Queries.entities(domain: .APM) { applications in
                if let apps = applications {
                    self.applications = apps
                }
            }
        }
    }
        
}

#Preview {
    ApplicationView()
}
