//
//  ChartViews.swift
//  NR Status
//
//  Created by Eric Baur on 10/13/24.
//

import SwiftUI

struct TimeseriesChartConfigView: View {
    let isComparable: Bool = false

    @Binding var fields: [SelectableField]
    @Binding var facets: [SelectableField]
    
    @Binding var config: ChartConfiguration
    
    var body: some View {
        GroupBox {
            HStack {
                if !isComparable && config.selectedFields.count == 1 && config.selectedFacets.count > 1 {
                    Toggle("Stacked", isOn: $config.isStacked).toggleStyle(.switch)
                }
                Toggle("Smoothed", isOn: $config.isSmoothed).toggleStyle(.switch)
                Toggle("Points", isOn: $config.showDataPoints).toggleStyle(.switch)
                if fields.count > 1 {
                    SeriesSelectionView(title: "Select fields...", fields: $fields)
                }
                if facets.count > 1 {
                    SeriesSelectionView(title: "Select facets...", fields: $facets)
                }
            }
        }
    }
}

//#Preview {
//    @Previewable @State var config: ChartConfiguration = .init()
//    TimeseriesChartConfigView(
//        fields: ["Field 1", "Field 2"],
//        facets: ["Facet 1", "Facet 2"],
//        config: $config
//    )
//}
