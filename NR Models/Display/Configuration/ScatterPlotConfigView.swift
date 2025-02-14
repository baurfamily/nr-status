//
//  ScatterPlotConfigView.swift
//  NR Status
//
//  Created by Eric Baur on 02/09/25.
//

import SwiftUI

struct ScatterPlotConfigView: View {
    let isComparable: Bool = false

    @Binding var config: ChartConfiguration
    
    var body: some View {
        GroupBox {
            Form {
                Toggle("Color facets", isOn: $config.plot.colorFacets)
                Toggle("X Log scale", isOn: $config.plot.xLogScale)
                Toggle("Y Log scale", isOn: $config.plot.yLogScale)

                SeriesDropdownView(
                    title: "X-Axis",
                    fields: config.fields.map(\.id),
                    selection: $config.plot.xField
                )
                
                SeriesDropdownView(
                    title: "Y-Axis",
                    fields: config.fields.map(\.id),
                    selection: $config.plot.yField
                )
                SeriesDropdownView(
                    title: "Point Size",
                    fields: config.fields.map(\.id),
                    selection: $config.plot.sizeField,
                    includeNone: true
                )
                
                
                if config.facets.all.count > 1 {
                    SeriesSelectionView(title: "Select facets...", fields: $config.facets.all)
                }
            }
        }
    }
}

#Preview("Basic config") {
    @Previewable @State var isPresented = true
    @Previewable @State var config: ChartConfiguration = .init(
        resultContainer: ChartSamples.sampleData(facet: .single, timeseries: true)!
    )
    GroupBox {
        Text("Chart...")
    }.inspector(isPresented: $isPresented) {
        ScatterPlotConfigView(config: $config)
    }
}

#Preview("Advanced config") {
    @Previewable @State var isPresented = true
    @Previewable @State var config: ChartConfiguration = .init(
        resultContainer: ChartSamples.sampleData(facet: .single, timeseries: true, size: .medium, statistics: true)!
    )
    GroupBox {
        Text("Chart...")
    }.inspector(isPresented: $isPresented) {
        ScatterPlotConfigView(config: $config)
    }
}
