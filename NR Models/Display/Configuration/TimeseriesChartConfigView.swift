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
            HStack {
                if !isComparable && config.selectedFields.count == 1 && config.selectedFacets.count > 1 {
                    Toggle("Stacked", isOn: $config.isStacked).toggleStyle(.switch)
                }
                Toggle("Smoothed", isOn: $config.isSmoothed).toggleStyle(.switch)
                Toggle("Points", isOn: $config.showDataPoints).toggleStyle(.switch)
                if config.fields.count > 1 {
                    SeriesSelectionView(title: "Select fields...", fields: $config.fields)
                }
                if config.facets.count > 1 {
                    SeriesSelectionView(title: "Select facets...", fields: $config.facets)
                }
            }
        }
    }
}

// I broke this enough that I need to rewrite it, not just update a bit
//#Preview {
//    @Previewable @State var config: ChartConfiguration = .init(
//        
//        fields: SelectableField.wrap(
//            ["Field 1", "Field 2", "Field 3", "Field 4"]
//        ), facets: SelectableField.wrap(
//            ["Facet 1", "Facet 2", "Facet 3", "Facet 4"]
//        )
//    )
//    TimeseriesChartConfigView(config: $config)
//    GroupBox {
//        HStack {
//            VStack {
//                ForEach(config.fields.filter(\.isSelected)) { Text($0.id) }
//            }
//            VStack {
//                ForEach(config.facets.filter(\.isSelected)) { Text($0.id) }
//            }
//        }
//    }
//}
