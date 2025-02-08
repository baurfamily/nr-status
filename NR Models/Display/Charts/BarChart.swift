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
    
    @State var switchFieldsAndFacets: Bool = false

    var data: [NrdbResults.Datum] { resultContainer.results.data }
    var metadata: NrdbMetadata { resultContainer.metadata }
    
    var selectedFacets: [String] { config.selectedFacets }
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
    
    func lineStyle(for comparison: NrdbResults.Datum.Comparison) -> StrokeStyle {
        if comparison == .current {
            return .init()
        } else {
            return .init( dash: [ 10, 5, 2, 5 ] )
        }
    }
    func dateFor(_ datum: NrdbResults.Datum) -> Date {
        if self.resultContainer.isComparable && datum.comparison == .previous{
            return self.resultContainer.adjustedTime(datum.beginTime!)
        } else {
            return datum.beginTime!
        }
    }
    
    var body: some View {
//        GroupBox {
//            HStack {
//                Toggle("Pivot Data", isOn: $switchFieldsAndFacets)
//                if config.fields.count > 1 {
//                    SeriesSelectionView(title: "Select fields...", fields: $config.fields)
//                } else { Text("fields?") }
//                if config.facets.count > 1 {
//                    SeriesSelectionView(title: "Select facets...", fields: $config.facets)
//                } else { Text("facets?") }
//            }
//            if !switchFieldsAndFacets && selectedFields.count != 1 {
//                Text("It is recomended that you eaither select a single field for display or pivot the data.")
//            }
//        }
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
