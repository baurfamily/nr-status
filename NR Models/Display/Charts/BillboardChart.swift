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
        config.resultContainer.results.data.filter {
            $0.facet == nil || selectedFacets.contains($0.facet!)
        }.flatMap { datum in
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
        selectedFields.first ?? ""
    }

    let columns = [
        GridItem(.adaptive(minimum: 200))
    ]

    var body: some View {
        if config.heightInLines != nil {
            GeometryReader { geometry in
                let width = max(geometry.size.width - 32, 1)
                let columnCount = max(1, min(data.count, Int((width + 16) / 216)))
                let rowCount = max(1, (data.count + columnCount - 1) / columnCount)
                let spacing = min(16, max(geometry.size.height, 0) / CGFloat(rowCount * 4))
                let tileWidth = max(1, (width - CGFloat(columnCount - 1) * 16) / CGFloat(columnCount))
                let tileHeight = max(1, (geometry.size.height - CGFloat(rowCount - 1) * spacing) / CGFloat(rowCount))
                let scale = min(tileWidth / 200, tileHeight / 135)

                LazyVGrid(
                    columns: Array(repeating: GridItem(.flexible(), spacing: 16), count: columnCount),
                    spacing: spacing
                ) {
                    ForEach(data, id: \.id) { item in
                        tile(for: item)
                            .frame(width: tileWidth / scale, height: tileHeight / scale)
                            .scaleEffect(scale)
                            .frame(width: tileWidth, height: tileHeight)
                    }
                }
                .padding(.horizontal, 16)
            }
        } else {
            compactGrid
        }
    }

    private var compactGrid: some View {
        LazyVGrid(columns: columns, spacing: 16) {
            ForEach(data, id: \.id) { item in
                tile(for: item)
            }
        }
        .padding(.horizontal)
    }

    @ViewBuilder private func tile(for item: NrdbResults.MiniDatum) -> some View {
        if config.billboard.showGauge {
            // Gauge styles have distinct concrete types.
            switch config.billboard.gaugeStyle {
            case .linear:
                GaugeTile(datum: item, max: config.billboard.gaugeMax, gaugeStyle: .linearCapacity)
            case .compactLinear:
                GaugeTile(datum: item, max: config.billboard.gaugeMax, gaugeStyle: .accessoryLinear)
            case .linearCapacity:
                GaugeTile(datum: item, max: config.billboard.gaugeMax, gaugeStyle: .accessoryLinearCapacity)
            case .circular:
                GaugeTile(datum: item, max: config.billboard.gaugeMax, gaugeStyle: .accessoryCircular)
            case .circularCapacity:
                GaugeTile(datum: item, max: config.billboard.gaugeMax, gaugeStyle: .accessoryCircularCapacity)
            }
        } else {
            BillboardTile(datum: item)
        }
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
