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
    var fillsAvailableSpace = false
    
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

    var body: some View {
        if fillsAvailableSpace {
            widgetGrid
        } else if config.heightInLines != nil {
            GeometryReader { geometry in
                let grid = ScaledBillboardGrid(itemCount: data.count, size: geometry.size)

                LazyVGrid(
                    columns: Array(repeating: GridItem(.flexible(minimum: 0), spacing: 16), count: grid.columns),
                    spacing: grid.spacing
                ) {
                    ForEach(data, id: \.id) { item in
                        tile(for: item)
                            .frame(width: grid.tileSize.width / grid.scale, height: grid.tileSize.height / grid.scale)
                            .scaleEffect(grid.scale)
                            .frame(width: grid.tileSize.width, height: grid.tileSize.height)
                    }
                }
                .padding(.horizontal, 16)
            }
        } else {
            compactGrid
        }
    }

    private var widgetGrid: some View {
        GeometryReader { geometry in
            let grid = ScaledBillboardGrid(
                itemCount: data.count, size: geometry.size, horizontalPadding: 0,
                maximumSpacing: 8, referenceSize: CGSize(width: 110, height: 100)
            )
            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(minimum: 0), spacing: 8), count: grid.columns),
                spacing: grid.spacing
            ) {
                ForEach(data, id: \.id) { item in
                    WidgetBillboardTile(datum: item, configuration: config.billboard, size: grid.tileSize)
                        .frame(width: grid.tileSize.width, height: grid.tileSize.height)
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
    }

    private var compactGrid: some View {
        BillboardGridLayout {
            ForEach(data, id: \.id) { item in
                tile(for: item)
            }
        }
        .padding(.horizontal, 16)
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

private struct ScaledBillboardGrid {
    var columns = 1
    var spacing: CGFloat = 0
    var tileSize = CGSize.zero
    var scale: CGFloat = 0

    init(
        itemCount: Int, size: CGSize, horizontalPadding: CGFloat = 16,
        maximumSpacing: CGFloat = 16, referenceSize: CGSize = CGSize(width: 200, height: 135)
    ) {
        let count = max(1, itemCount)
        let width = max(1, size.width - horizontalPadding * 2)
        let height = max(1, size.height)
        for columns in 1...count {
            let tileWidth = (width - CGFloat(columns - 1) * maximumSpacing) / CGFloat(columns)
            guard tileWidth > 0 else { break }
            let rows = (count + columns - 1) / columns
            let spacing = min(maximumSpacing, height / CGFloat(rows * 4))
            let tileHeight = (height - CGFloat(rows - 1) * spacing) / CGFloat(rows)
            let scale = min(tileWidth / referenceSize.width, tileHeight / referenceSize.height)
            // Ties keep fewer columns, avoiding unnecessary empty cells in the last row.
            if scale > self.scale {
                self.columns = columns
                self.spacing = spacing
                self.tileSize = CGSize(width: tileWidth, height: tileHeight)
                self.scale = scale
            }
        }
    }
}

private struct WidgetBillboardTile: View {
    let datum: NrdbResults.MiniDatum
    let configuration: BillboardConfiguration
    let size: CGSize

    private var isCircular: Bool {
        configuration.showGauge && [.circular, .circularCapacity].contains(configuration.gaugeStyle)
    }
    private var upperBound: Double {
        configuration.gaugeMax.isFinite && configuration.gaugeMax > 0 ? configuration.gaugeMax : 100
    }
    private var fraction: Double { min(1, max(0, datum.value / upperBound)) }
    private var captionSize: CGFloat { max(1, min(size.width * 0.16, size.height * 0.14)) }
    private var diameter: CGFloat { max(1, min(size.width, size.height * (datum.facet == nil ? 0.75 : 0.6))) }
    private var numberFormat: FloatingPointFormatStyle<Double> {
        .number.notation(.compactName).precision(.significantDigits(2))
    }

    var body: some View {
        VStack(spacing: min(6, size.height * 0.04)) {
            if let facet = datum.facet {
                Text(facet).font(.system(size: captionSize, weight: .light))
            }
            if isCircular {
                circularGauge
            } else {
                Text(datum.value, format: numberFormat)
                    .font(.system(size: max(1, min(size.width * 0.6, size.height * valueHeight)), weight: .bold))
                    .monospacedDigit()
            }
            Text(datum.field)
                .font(.system(size: captionSize))
                .fontWidth(.condensed)
            if configuration.showGauge && !isCircular {
                linearGauge
                HStack {
                    Text(0, format: numberFormat)
                    Spacer(minLength: 0)
                    Text(upperBound, format: numberFormat)
                }
                .font(.system(size: max(1, captionSize * 0.8)))
                .foregroundStyle(.secondary)
            }
        }
        .lineLimit(1)
        .minimumScaleFactor(0.2)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var valueHeight: CGFloat {
        configuration.showGauge ? 0.3 : datum.facet == nil ? 0.55 : 0.44
    }

    private var circularGauge: some View {
        let span = configuration.gaugeStyle == .circular ? 0.75 : 1.0
        let rotation = configuration.gaugeStyle == .circular ? 135.0 : -90.0
        let stroke = StrokeStyle(lineWidth: diameter * 0.09, lineCap: .round)
        return ZStack {
            Circle().trim(from: 0, to: span)
                .stroke(Color.primary.opacity(0.12), style: stroke)
                .rotationEffect(.degrees(rotation))
            Circle().trim(from: 0, to: span * fraction)
                .stroke(Color.accentColor, style: stroke)
                .rotationEffect(.degrees(rotation))
            Text(datum.value, format: numberFormat)
                .font(.system(size: diameter * 0.32, weight: .bold))
                .monospacedDigit()
                .padding(diameter * 0.12)
        }
        .padding(diameter * 0.05)
        .frame(width: diameter, height: diameter)
    }

    private var linearGauge: some View {
        let marker = configuration.gaugeStyle == .compactLinear
        let isLinear = configuration.gaugeStyle == .linear
        let thickness = max(3, min(isLinear ? 16 : 8, size.height * (isLinear ? 0.12 : 0.08)))
        let cornerRadius: CGFloat = isLinear ? 2 : thickness / 2
        return GeometryReader { geometry in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: cornerRadius).fill(Color.primary.opacity(0.12))
                if marker {
                    Circle().fill(Color.accentColor)
                        .frame(width: thickness, height: thickness)
                        .offset(x: max(0, geometry.size.width - thickness) * fraction)
                } else {
                    RoundedRectangle(cornerRadius: cornerRadius).fill(Color.accentColor)
                        .frame(width: geometry.size.width * fraction)
                }
            }
        }
        .frame(height: thickness)
    }
}

private struct BillboardGridLayout: Layout {
    private let spacing: CGFloat = 16
    private let minimumColumnWidth: CGFloat = 200

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width.flatMap { $0.isFinite ? $0 : nil }
            ?? CGFloat(subviews.count) * (minimumColumnWidth + spacing) - spacing
        let grid = metrics(width: max(0, width), subviews: subviews)
        return CGSize(
            width: max(0, width),
            height: grid.rowHeights.reduce(0, +) + CGFloat(max(0, grid.rowHeights.count - 1)) * spacing
        )
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let grid = metrics(width: bounds.width, subviews: subviews)
        var y = bounds.minY
        for (row, height) in grid.rowHeights.enumerated() {
            for column in 0..<grid.columns {
                let index = row * grid.columns + column
                guard index < subviews.count else { break }
                subviews[index].place(
                    at: CGPoint(
                        x: bounds.minX + CGFloat(column) * (grid.columnWidth + spacing) + grid.columnWidth / 2,
                        y: y + height / 2
                    ),
                    anchor: .center,
                    proposal: ProposedViewSize(width: grid.columnWidth, height: height)
                )
            }
            y += height + spacing
        }
    }

    private func metrics(width: CGFloat, subviews: Subviews) -> (columns: Int, columnWidth: CGFloat, rowHeights: [CGFloat]) {
        let columns = max(1, min(subviews.count, Int((width + spacing) / (minimumColumnWidth + spacing))))
        let columnWidth = max(0, (width - CGFloat(columns - 1) * spacing) / CGFloat(columns))
        var rowHeights = Array(repeating: CGFloat.zero, count: (subviews.count + columns - 1) / columns)
        for (index, subview) in subviews.enumerated() {
            let height = subview.sizeThatFits(ProposedViewSize(width: columnWidth, height: nil)).height
            rowHeights[index / columns] = max(rowHeights[index / columns], height)
        }
        return (columns, columnWidth, rowHeights)
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
