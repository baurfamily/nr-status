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
            HStack {
                if let alertSeverity = app.alertSeverity {
                    Text("\(alertSeverity)")
                } else {
                    Text("NO ALERT DATA")
                }
                Text(app.name ?? "Unknown")
                Text(app.domain?.rawValue ?? "n/a")
            }
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
