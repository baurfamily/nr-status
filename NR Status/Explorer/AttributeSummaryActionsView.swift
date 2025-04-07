//
//  AttributeSummaryProxyView.swift
//  NR Status
//
//  Created by Eric Baur on 3/16/25.
//

import SwiftUI

struct AttributeSummaryActionsView : View {
    let attribute: Attribute
    @Binding var query: QueryBuilder

    @State var summary: AttributeSummary?
    
    func makeBinding(for key: String) -> Binding<Bool> {
        return Binding(
            get: {
                query.contains(aggregate: key, with: attribute)
            },
            set: { newVal in
                if newVal {
                    query.add(aggregate: key, with: attribute)
                } else {
                    query.remove(aggregate: key, with: attribute)
                }
            }
        )
    }
    
    var body: some View {
        VStack {
            Grid(alignment: .trailingFirstTextBaseline) {
                GridRow {
                    Spacer()
                    Toggle(isOn: Binding(
                        get: { query.contains(attribute: attribute) },
                        set: { $0 ? query.add(attribute: attribute) : query.remove(attribute: attribute)}
                    )) { Text("Select") }
                        .toggleStyle(.titleShift)
                        .disabled(query.isFaceted)
                    Spacer()
                }
                GridRow {
                    Spacer()
                    Toggle(isOn: Binding(
                        get: { query.contains(facet: attribute) },
                        set: { newVal in
                            if newVal {
                                query.add(facet: attribute)
                            } else {
                                query.remove(facet: attribute)
                            }
                        }
                    )) { Text("Facet") }
                        .toggleStyle(.titleShift)
                    Spacer()
                }
                Divider()
                GridRow {
                    Spacer()
                    Toggle(isOn: makeBinding(for: "count")) {
                        Text("Count")
                    }.toggleStyle(.titleShift)
                    SparklineChart(data: summary?.timeseriesResultsContainer?.results.data ?? [], key: "count")
                    Spacer()
                }
                GridRow {
                    Spacer()
                    Toggle(isOn: makeBinding(for: "countUnique")) {
                        Text("Count Unique")
                    }.toggleStyle(.titleShift)
                    SparklineChart(data: summary?.timeseriesResultsContainer?.results.data ?? [], key: "uniqueCount.\(attribute.key)")
                    Spacer()
                }
                if attribute.type == "numeric" {
                    Divider()
                    GridRow {
                        Spacer()
                        Toggle(isOn: makeBinding(for: "average")) {
                            Text("Average")
                        }.toggleStyle(.titleShift)
                        SparklineChart(data: summary?.timeseriesResultsContainer?.results.data ?? [], key: "average.\(attribute.key)")
                        Spacer()
                    }
                    GridRow {
                        Spacer()
                        Toggle(isOn: makeBinding(for: "stddev")) {
                            Text("Std. Dev.")
                        }.toggleStyle(.titleShift)
                        SparklineChart(data: summary?.timeseriesResultsContainer?.results.data ?? [], key: "stddev.\(attribute.key)")
                        Spacer()
                    }
                    GridRow {
                        Spacer()
                        Toggle(isOn: makeBinding(for: "min")) {
                            Text("Minimum")
                        }.toggleStyle(.titleShift)
                        SparklineChart(data: summary?.timeseriesResultsContainer?.results.data ?? [], key: "min.\(attribute.key)")
                        Spacer()
                    }
                    GridRow {
                        Spacer()
                        Toggle(isOn: makeBinding(for: "max")) {
                            Text("Maximum")
                        }.toggleStyle(.titleShift(activeColor: .green))
                        SparklineChart(data: summary?.timeseriesResultsContainer?.results.data ?? [], key: "max.\(attribute.key)")
                        Spacer()
                    }
                }
            }
            if let summary {
                AttributeSummaryView(summary: summary)
                    .frame(maxWidth: .infinity, maxHeight: 500)
            }
        }.task {
            Task {
                self.summary = await AttributeSummary.generate(from: attribute)
            }
        }
    }
}

#Preview {
    @Previewable @State var query = QueryBuilder(event: "Transaction")
    AttributeSummaryActionsView(attribute: .init(
        event: "Transaction",
        type: "numeric",
        key: "duration"
    ), query: $query).frame(width: 400, height: 600)
}
