//
//  BillboardChartConfigView.swift
//  NR Status
//
//  Created by Eric Baur on 02/11/25.
//

import SwiftUI

struct BillboardChartConfigView: View {
    @Binding var config: ChartConfiguration
    @State var title: String = "...select"
    
    var body: some View {
        GroupBox {
            Form {
                Toggle("Show guage", isOn: $config.billboard.showGauge)
                if config.billboard.showGauge {
                    Menu("Style: \(title)") {
                        Button(action: {
                            config.billboard.gaugeStyle = .circular
                            title = "Speedometer"
                        }) {
                            Text("Speedometer")
                        }
                        Button(action: {
                            config.billboard.gaugeStyle = .circularCapacity
                            title = "Circular Capacity"
                        }) {
                            Text("Circular Capacity")
                        }
                        Button(action: {
                            config.billboard.gaugeStyle = .linear
                            title = "Linear"
                        }) {
                            Text("Linear")
                        }
                        Button(action: {
                            config.billboard.gaugeStyle = .compactLinear
                            title = "Compact Linear"
                        }) {
                            Text("Compact Linear")
                        }
                        Button(action: {
                            config.billboard.gaugeStyle = .linearCapacity
                            title = "Linear Capacity"
                        }) {
                            Text("Linear Capacity")
                        }
                    }
                    TextField("Max value", value: $config.billboard.gaugeMax, format: .number)
                }
                
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
        BillboardChartConfigView(config: $config)
    }
}
