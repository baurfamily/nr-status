//
//  ChartViews.swift
//  NR Status
//
//  Created by Eric Baur on 10/10/24.
//

import SwiftUI
import Charts

struct BarChart: View {
    var config: ChartConfiguration
    var categoryAxisVisible = true
    var legendVisibility: Visibility = .automatic
    
    var resultContainer: NrdbResultContainer {
        config.resultContainer
    }
    
    var switchFieldsAndFacets: Bool { config.bar.pivotData }

    var data: [NrdbResults.Datum] { resultContainer.results.data }
    var metadata: NrdbMetadata { resultContainer.metadata }
    
    var selectedFacets: [String] { config.facets.selected }
    var selectedFields: [String] { config.selectedFields }
    
    var dimensionOne: [String] { switchFieldsAndFacets ? selectedFacets : selectedFields }
    var dimensionTwo: [String] { switchFieldsAndFacets ? selectedFields : selectedFacets}
    
    var filteredData: [NrdbResults.Datum] {
        if switchFieldsAndFacets {
            return data
        } else {
            return data.filter {
                $0.facet == nil || selectedFacets.contains($0.facet!)
            }
        }
    }

    var effectiveLegendVisibility: Visibility {
        guard legendVisibility == .automatic, categoryAxisVisible, !switchFieldsAndFacets else {
            return legendVisibility
        }
        let rows = filteredData
        let repeatsCategories = !rows.isEmpty && rows.allSatisfy { !$0.isTimeseries && $0.isFaceted }
        return repeatsCategories ? .hidden : .automatic
    }

    func seriesNames(for field: String, in datum: NrdbResults.Datum ) -> (String,String) {
        let prefix = datum.isComparable ? "\(datum.comparison): " : ""
        let facetPrefix = datum.isFaceted ? "Facet" : "Data"
        
        let groupName = facetPrefix
        let fieldName: String
        if let facet = datum.facet {
            fieldName = "\(prefix)\(facet)(\(field))"
        } else {
            fieldName = "\(prefix)\(field)"
        }
        
        return (groupName, fieldName)
    }

    @ChartContentBuilder
    func timeseriesBar(for field: String, in datum: NrdbResults.Datum) -> some ChartContent {
        let series = seriesNames(for: field, in: datum)
        let bar = BarMark(
            x: .value("Timestamp", resultContainer.comparisonDate(for: datum) ?? datum.beginTime!),
            y: .value(field, datum.numberFields[field] ?? 0)
        )
        .foregroundStyle(by: .value(series.0, series.1))

        if resultContainer.isComparable {
            bar.position(by: .value("Comparison", datum.comparison.rawValue))
        } else {
            bar
        }
    }
    
    var body: some View {
        Chart(filteredData) { datum in
            if datum.isTimeseries {
                ForEach(selectedFields, id: \.self) { fieldName in
                    timeseriesBar(for: fieldName, in: datum)
                }
            } else if switchFieldsAndFacets {
                ForEach(selectedFields, id:\.self) { fieldName in
                    if let facet = datum.facet {
                        if selectedFacets.contains(facet) {
                            BarMark(
                                x: .value( "Field", fieldName ),
                                y: .value( facet, datum.numberFields[fieldName] ?? 0 )
                            ).foregroundStyle(
                                by: .value(
                                    Text(verbatim: facet),
                                    facet
                                )
                            )
                        }
                    }
                }
            } else {
                ForEach(selectedFields, id:\.self) { fieldName in
                    if resultContainer.isFaceted, let facet = datum.facet {
                        BarMark(
                            x: .value("Facet", facet),
                            y: .value(fieldName, datum.numberFields[fieldName] ?? 0)
                        )
                        .foregroundStyle(
                            by: .value(
                                Text(verbatim: facet),
                                facet
                            )
                        )
                    } else if resultContainer.isMultiFaceted, let facets = datum.facets, facets.count >= 2 {
                        BarMark(
                            x: .value("Facet", facets[1]),
                            y: .value(fieldName, datum.numberFields[fieldName] ?? 0)
                        )
                        .foregroundStyle(
                            by: .value( "Facet", facets[0] )
                        )
                    }
                }
            }
        }
        .chartLegend(effectiveLegendVisibility)
    }
}

#Preview("Timeseries (faceted)") {
    // not really a good example of a *useful* bar chart, but the data is shaped the way I want
    if let single = ChartSamples.sampleData(facet: .single, size: .medium, statistics: false) {
//        ConfigurableChartView(config: ChartConfiguration(resultContainer: single))
        BarChart(config: ChartConfiguration(resultContainer: single))
            .chartLegend(.hidden)
    } else {
        Text("No sample data")
    }
}

#Preview("Single facet (small)") {
    if let single = ChartSamples.sampleData(facet: .single, timeseries: false, comparable: false, size: .small) {
        Text("data \(single.results.data.count)")
        BarChart(config: .init(resultContainer: single))
    } else {
        Text("No sample data")
        Text(ChartSamples.sampleFilename(facet: .single, timeseries: false, comparable: false, size: .small))
    }
}

#Preview("Double facet (small)") {
    if let double = ChartSamples.sampleData(facet: .multi, timeseries: false, comparable: false, size: .small) {
        BarChart(config: .init(resultContainer: double))
    } else {
        Text("No sample data")
        Text(ChartSamples.sampleFilename(facet: .multi, timeseries: false, comparable: false, size: .small))
    }
}
