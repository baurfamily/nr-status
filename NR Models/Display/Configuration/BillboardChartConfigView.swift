//
//  BillboardChartConfigView.swift
//  NR Status
//
//  Created by Eric Baur on 02/11/25.
//

import SwiftUI

struct BillboardChartConfigView: View {
    @Binding var config: ChartConfiguration
    
    var body: some View {
        GroupBox {
            Form {
                Toggle("Show gauge", isOn: $config.billboard.showGauge)
                if config.billboard.showGauge {
                    Picker("Style", selection: $config.billboard.gaugeStyle) {
                        ForEach(BillboardConfiguration.GaugeStyle.allCases, id: \.self) { style in
                            Text(style.rawValue).tag(style)
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
