//
//  ChartViews.swift
//  NR Status
//
//  Created by Eric Baur on 10/13/24.
//

import SwiftUI

struct TimeseriesChartConfigView: View {
    let isComparable: Bool = false

    @Binding var config: ChartConfiguration
    
    var body: some View {
        GroupBox {
            Form {
                if !isComparable && config.selectedFields.count == 1 && config.facets.selected.count > 1 {
                    Toggle("Stacked", isOn: $config.timeseries.isStacked)
                }
                Toggle("Smoothed", isOn: $config.timeseries.isSmoothed)
                Toggle("Lines", isOn: $config.timeseries.showLines)
                    .onChange(of: config.timeseries.showLines) { _, newValue in
                        if !newValue {
                            config.timeseries.showDataPoints = true
                        }
                    }
                Toggle("Points", isOn: $config.timeseries.showDataPoints)
                    .onChange(of: config.timeseries.showDataPoints) { _, newValue in
                        if !newValue {
                            config.timeseries.showLines = true
                        }
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

// I broke this enough that I need to rewrite it, not just update a bit
#Preview {
    @Previewable @State var isPresented = true
    @Previewable @State var config: ChartConfiguration = .init(
        resultContainer: ChartSamples.sampleData(facet: .single, timeseries: true)!
        
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
        TimeseriesChartConfigView(config: $config)
    }
}
