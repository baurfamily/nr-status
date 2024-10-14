//
//  ChartViews.swift
//  NR Status
//
//  Created by Eric Baur on 10/13/24.
//

import SwiftUI

struct TimeseriesChartConfigView: View {
    let isComparable: Bool = false

    var fields: [String]
    var facets: [String]
    
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
                    SeriesSelectionView(fieldList: fields, selectedFields: $config.selectedFields)
                }
                if facets.count > 1 {
                    SeriesSelectionView(fieldList: facets, selectedFields: $config.selectedFacets)
                }
            }
        }
    }
}
