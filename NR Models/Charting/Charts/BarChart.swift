//
//  ChartViews.swift
//  NR Status
//
//  Created by Eric Baur on 10/10/24.
//

import SwiftUI
import Charts

struct BarChart: View {
    var resultsContainer: NrdbResultContainer
    @State var config: ChartConfiguration
    @State var switchFieldsAndFacets: Bool = false

    var data: [NrdbResults.Datum] { resultsContainer.results.data }
    var metadata: NrdbMetadata { resultsContainer.metadata }
    
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
        if resultsContainer.results.isComparable && datum.comparison == .previous{
             return resultsContainer.results.adjustedTime(datum.beginTime!)
        } else {
            return datum.beginTime!
        }
    }
    
    init(resultsContainer: NrdbResultContainer) {
        self.resultsContainer = resultsContainer
        
        var fields: [SelectableField] = []
        var facets: [SelectableField] = []
        
        if let first = resultsContainer.results.data.first {
            fields = SelectableField.wrap( first.numberFields.keys.sorted() )
        }
        facets = SelectableField.wrap( resultsContainer.results.allFacets.sorted() )
                
        self.config = .init(
            isStacked: false,
            isSmoothed: true,
            showDataPoints: false,
            fields: fields,
            facets: facets
        )
    }
    
    var body: some View {
        GroupBox {
            HStack {
                Toggle("Pivot Data", isOn: $switchFieldsAndFacets)
                if config.fields.count > 1 {
                    SeriesSelectionView(title: "Select fields...", fields: $config.fields)
                } else { Text("fields?") }
                if config.facets.count > 1 {
                    SeriesSelectionView(title: "Select facets...", fields: $config.facets)
                } else { Text("facets?") }
            }
            if !switchFieldsAndFacets && selectedFields.count != 1 {
                Text("It is recomended that you eaither select a single field for display or pivot the data.")
            }
        }
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
                }
            }
        }
    }
}

#Preview("Single facet (small)") {
    if let single = ChartSamples.sampleData(facet: .single, timeseries: false, comparable: false, size: .small) {
        Text("data \(single.results.data.count)")
        BarChart(resultsContainer: single)
    } else {
        Text("No sample data")
        Text(ChartSamples.sampleFilename(facet: .single, timeseries: false, comparable: false, size: .small))
    }
}

#Preview("Double facet (small)") {
    if let double = ChartSamples.sampleData(facet: .multi, timeseries: false, comparable: false, size: .small) {
        BarChart(resultsContainer: double)
    } else {
        Text("No sample data")
        Text(ChartSamples.sampleFilename(facet: .multi, timeseries: false, comparable: false, size: .small))
    }
}
