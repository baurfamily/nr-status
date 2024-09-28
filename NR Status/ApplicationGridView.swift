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
    @State var applications: [Application] = Application.all()
//    @Environment(\.verticalSizeClass) var verticalSizeClass: UserInterfaceSizeClass?

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
//        GeometryReader { geometry in
//            ScrollView {
//                ForEach(1..<24) { item in
////                    if self.verticalSizeClass == .regular {
////                        HStack {
////                            Spacer(minLength: geometry.size.width * 0.15)
////                            Rectangle()
////                                .foregroundColor(.green)
////                                .frame(width: geometry.size.width * 0.70,
////                                       height: geometry.size.height * 0.3)
////                            Spacer(minLength: geometry.size.width * 0.15)
////                        }
////                    } else {
//                        HStack {
//                            Spacer(minLength: geometry.size.width * 0.05)
//                            Rectangle()
//                                .foregroundColor(.green)
//                                .frame(width: geometry.size.width * 0.40,
//                                       height: geometry.size.height)
//                            Spacer(minLength: geometry.size.width * 0.05)
//                            Rectangle()
//                                .foregroundColor(.pink)
//                                .frame(width: geometry.size.width * 0.40,
//                                       height: geometry.size.height)
//                            Spacer(minLength: geometry.size.width * 0.05)
//                        }
////                    }
//                }
//            }
//        }
    }
}

#Preview {
    ApplicationGridView(applications: Application.samples(count: 100))
}
