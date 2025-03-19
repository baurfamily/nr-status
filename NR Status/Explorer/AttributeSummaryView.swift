//
//  AttributeSummaryView.swift
//  NR Status
//
//  Created by Eric Baur on 3/18/25.
//

import SwiftUI

struct AttributeSummaryView : View {
    @State var summary: AttributeSummary
    
    var body: some View {
        Grid {
            GridRow {
                VStack {
                    Text("Cardinality: ").font(.headline)
                    Text(String(summary.cardinality)).font(.largeTitle)
                }
                Form {
                    if let avg = summary.average {
                        Text("Average: ").font(.headline) + Text(String(format: "%.2f", avg))
                    }
                    if let min = summary.minimum, let max = summary.maximum {
                        Text("Min: ").font(.headline) + Text(String(format: "%.2f", min))
                        Text("Max: ").font(.headline) + Text(String(format: "%.2f", max))
                    }
                }
            }
        }
        TabView {
            Tab("Samples", systemImage: "list.bullet") {
                List {
                    ForEach(summary.samples, id: \.self) { Text($0) }
                }
            }
            Tab("Charts", systemImage: "chart.dots.scatter") {
                Text("nothing to see here")
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    AttributeSummaryView(
        summary: AttributeSummary(
            attribute: Attribute(
                event: "Attributes",
                type: "numeric",
                key: "testAttr",
                isSelected: true
            ),
            cardinality: 2345,
            average: 56.75,
            minimum: 10,
            maximum: 75,
            samples: [ "10", "14", "45", "100", "75" ],
            timeseriesResultsContainer: nil
        )
    )
}
