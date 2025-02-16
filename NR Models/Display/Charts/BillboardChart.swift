//
//  ChartViews.swift
//  NR Status
//
//  Created by Eric Baur on 10/10/24.
//

import SwiftUI
import Charts

struct BillboardChart: View {
    var config: ChartConfiguration
    
    var resultContainer: NrdbResultContainer {
        config.resultContainer
    }
    
    var data: [NrdbResults.MiniDatum] {
        config.resultContainer.results.data.flatMap { datum in
            config.selectedFields.map { field in
                NrdbResults.MiniDatum(
                    field: field,
                    facet: datum.facet,
                    value: datum.numberFields[field] ?? 0
                )
            }
        }
    }
    
    var metadata: NrdbMetadata { config.resultContainer.metadata }
    
    var selectedFacets: [String] { config.facets.selected }
    var selectedFields: [String] { config.selectedFields }
    
    var selectedField : String {
        guard !selectedFields.isEmpty else { return "" }
        return selectedFields.first!
    }

    let columns = [
        GridItem(.adaptive(minimum: 200))
    ]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 50) {
            ForEach(data, id: \.id) { item in
                if config.billboard.showGauge {
                    // I couldn't get generics working here...
                    if config.billboard.gaugeStyle == .linear {
                        GaugeTile(
                            datum: item,
                            max: config.billboard.gaugeMax,
                            gaugeStyle: .linearCapacity
                        )
                    } else if config.billboard.gaugeStyle == .compactLinear {
                        GaugeTile(
                            datum: item,
                            max: config.billboard.gaugeMax,
                            gaugeStyle: .accessoryLinear
                        )
                    } else if config.billboard.gaugeStyle == .linearCapacity {
                        GaugeTile(
                            datum: item,
                            max: config.billboard.gaugeMax,
                            gaugeStyle: .accessoryLinearCapacity
                        )
                    } else if config.billboard.gaugeStyle == .circular {
                        GaugeTile(
                            datum: item,
                            max: config.billboard.gaugeMax,
                            gaugeStyle: .accessoryCircular
                        )
                    } else if config.billboard.gaugeStyle == .circularCapacity {
                        GaugeTile(
                            datum: item,
                            max: config.billboard.gaugeMax,
                            gaugeStyle: .accessoryCircularCapacity
                        )
                    } else {
                        GaugeTile(
                            datum: item,
                            max: config.billboard.gaugeMax,
                            gaugeStyle: .linearCapacity
                        );
                    }
                } else {
                    BillboardTile(datum: item)
                }
            }
        }
        .padding(.horizontal)
    }
}

struct GaugeTile<G>: View where G : GaugeStyle {
    let datum: NrdbResults.MiniDatum
    let min: Double = 0
    let max: Double
    var gaugeStyle: G
    
    let numberFormat = FloatingPointFormatStyle<Double>().notation(.compactName).precision(.significantDigits(2))
    let gradient = Gradient(colors: [.green, .yellow, .red])

    var body: some View {
        Gauge(value: datum.value, in: min...max) {
            Text(datum.field)
                .font(.system(size: 25))
                .fontWidth(.condensed)
            if let facet  = datum.facet {
                Text("(\(facet))")
                    .font(.system(size: 15, weight: .light))
                    .fontWidth(.condensed)
            }
        } currentValueLabel: {
            Text(datum.value, format: numberFormat)
        } minimumValueLabel: {
            Text(min, format: numberFormat)
        } maximumValueLabel: {
            Text(max, format: numberFormat)
        }
        .gaugeStyle(gaugeStyle)
//        .tint(gradient)
    }
}

struct BillboardTile : View {
    let datum: NrdbResults.MiniDatum
    
    var body: some View {
        VStack {
            if let facet = datum.facet {
                Text(facet)
                    .font(.system(size: 15, weight: .light))
                    .fontWidth(.condensed)
            }
            Text(datum.value, format: .number.notation(.compactName).precision(.significantDigits(2)))
                .fontWidth(.expanded)
                .font(.system(size: 60, weight: .bold))
            Text(datum.field)
                .font(.system(size: 25))
                .fontWidth(.condensed)
        }
        .minimumScaleFactor(0.01)
    }
}

#Preview("Single facet (tiny)", traits: .fixedLayout(width: 300, height: 300)) {
    Group {
        if let single = ChartSamples.sampleData(timeseries: false, size: .tiny, statistics: true) {
            BillboardChart(config: .init(resultContainer: single))
                .frame(width: 400, height: 400)
        } else {
            Text("No sample data")
        }
    }
}

#Preview("Single facet (medium)") {
    if let single = ChartSamples.sampleData(facet: .single, timeseries: false, comparable: false, size: .medium) {
        Text("data \(single.results.data.count)")
        BillboardChart(config: .init(resultContainer: single))
            .frame(width: 400, height: 400)
    } else {
        Text("No sample data")
        Text(ChartSamples.sampleFilename(facet: .single, timeseries: false, comparable: false, size: .medium))
    }
}

#Preview("Double facet (small)") {
    if let double = ChartSamples.sampleData(facet: .multi, timeseries: false, comparable: false, size: .small) {
        BillboardChart(config: .init(resultContainer: double))
    } else {
        Text("No sample data")
        Text(ChartSamples.sampleFilename(facet: .multi, timeseries: false, comparable: false, size: .small))
    }
}
