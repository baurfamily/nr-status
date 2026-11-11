//
//  ApplicationView.swift
//  NR Status
//
//  Created by Eric Baur on 9/21/24.
//

import SwiftUI

struct ApplicationView: View {
    @State var applications: [Application] = []
    
    var body: some View {
        List(applications, id: \.guid) { app in
            HStack {
                Text(app.alertSeverity.rawValue)
                Text(app.name)
            }
        }
        .task {
            if applications.isEmpty {
                applications = await Application.all()
            }
        }
    }
}

#Preview {
    ApplicationView(applications: [
        Application.sample()
    ])
}
#Preview {
    ApplicationView(applications: Application.samples(count: 10))
}
