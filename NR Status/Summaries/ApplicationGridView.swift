//
//  ApplicationGridView.swift
//  NR Status
//
//  Created by Eric Baur on 9/26/24.
//

import SwiftUI
import HexGrid

extension Application : OffsetCoordinateProviding, Identifiable {
    var id: String {
        return guid
    }
    
    var offsetCoordinate: OffsetCoordinate {
        return OffsetCoordinate(row: Int.random(in: 0..<5), col: Int.random(in: 0..<5))
    }
}

struct ApplicationGridView: View {
    @State var applications: [Application] = []

    var body: some View {
        HexGrid(applications, spacing: 5) { application in
            switch application.alertSeverity {
            case .CRITICAL:         Color.red.opacity(1)
            case .NOT_ALERTING:     Color.green.opacity(1)
            case .NOT_CONFIGURED:   Color.gray.opacity(1)
            case .WARNING:          Color.orange.opacity(1)
            }
            Text(application.name)
        }
        .task {
            if applications.isEmpty {
                Application.all() { applications = $0 }
            }
        }
    }
}

#Preview {
    ApplicationGridView(applications: Application.samples(count: 100))
}
