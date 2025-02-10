//
//  PieChartConfigView.swift
//  NR Status
//
//  Created by Eric Baur on 10/13/24.
//

import SwiftUI

struct PieChartConfigView: View {
    @Binding var config: ChartConfiguration
    
    var body: some View {
        GroupBox {
            Form {
                Toggle("Donut", isOn: $config.pie.isDonut)
                Toggle("Separated", isOn: $config.pie.isSeparated)
                Stepper("Show \(config.pie.otherThreshold) facets", value: $config.pie.otherThreshold, in: 2...15)
                
                if config.fields.count > 1 {
                    SeriesSelectionView(title: "Select fields...", fields: $config.fields, singleValue: true)
                }
                if config.facets.all.count > 1 {
                    SeriesSelectionView(title: "Select facets...", fields: $config.facets.all)
                }
            }
        }
    }
}

// I broke this enough that I need to rewrite it, not just update a bit
#Preview {
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
        PieChartConfigView(config: $config)
    }
}
