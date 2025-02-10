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
    
    var body: some View {
        Chart(filteredData) { datum in
            if switchFieldsAndFacets {
                ForEach(selectedFields, id:\.self) { fieldName in
                    if let facet = datum.facet {
                        if selectedFacets.contains(facet) {
                            BarMark(
                                x: .value( "Field", fieldName ),
                                y: .value( facet, datum.numberFields[fieldName]! )
                            ).foregroundStyle(
                                by: .value(
                                    Text(verbatim: datum.facet!),
                                    datum.facet!
                                )
                            )
                        }
                    }
                }
            } else {
                ForEach(selectedFields, id:\.self) { fieldName in
                    if resultContainer.isFaceted {
                        BarMark(
                            x: .value("Facet", datum.facet!),
                            y: .value(fieldName, datum.numberFields[fieldName]!)
                        )
                        .foregroundStyle(
                            by: .value(
                                Text(verbatim: datum.facet!),
                                datum.facet!
                            )
                        )
                    } else if resultContainer.isMultiFaceted {
                        BarMark(
                            x: .value("Facet", datum.facets![1]),
                            y: .value(fieldName, datum.numberFields[fieldName]!)
                        )
                        .foregroundStyle(
                            by: .value( "Facet", datum.facets![0] )
                        )
                    }
                }
            }
        }
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
