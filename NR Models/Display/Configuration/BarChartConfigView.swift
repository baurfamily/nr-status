//
//  BarChartConfigView.swift
//  NR Status
//
//  Created by Eric Baur on 10/13/24.
//

import SwiftUI

struct BarChartConfigView: View {
    @Binding var config: ChartConfiguration
    
    var body: some View {
        GroupBox {
            Form {
                Toggle("Pivot Fields & Facets", isOn: $config.bar.pivotData)
                Stepper("Show \(config.bar.otherThreshold) facets", value: $config.bar.otherThreshold, in: 2...15)
                
                if config.fields.count > 1 {
                    SeriesSelectionView(title: "Select fields...", fields: $config.fields)
                }
                if config.facets.all.count > 1 {
                    SeriesSelectionView(title: "Select facets...", fields: $config.facets.all)
                }
            }
        }
    }
}

#Preview("Single Facet") {
    @Previewable @State var isPresented = true
    @Previewable @State var config: ChartConfiguration = .init(
        resultContainer: ChartSamples.sampleData(facet: .single, timeseries: false)!
        
    )
    GroupBox {
        VStack {
            VStack {
                ForEach(config.fields.filter(\.isSelected)) { Text($0.id) }
            }
            Divider()
            VStack {
                ForEach(config.facets.all.filter(\.isSelected)) { Text($0.id) }
            }
        }
    }.inspector(isPresented: $isPresented) {
        BarChartConfigView(config: $config)
    }
}

//#Preview("Multi-Facet") {
//    @Previewable @State var isPresented = true
//    @Previewable @State var config: ChartConfiguration = .init(
//        resultContainer: ChartSamples.sampleData(facet: .multi, timeseries: false)!
//        
//    )
//    GroupBox {
//        VStack {
//            VStack {
//                ForEach(config.fields.filter(\.isSelected)) { Text($0.id) }
//            }
//            Divider()
//            VStack {
//                ForEach(config.facets.all.filter(\.isSelected)) { Text($0.id) }
//            }
//        }
//    }.inspector(isPresented: $isPresented) {
//        BarChartConfigView(config: $config)
//    }
//}
