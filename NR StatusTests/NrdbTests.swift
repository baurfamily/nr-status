//
//  NrdbTests.swift
//  NR StatusTests
//

import Testing
import Foundation
@testable import NR_Status

struct NrdbTests {
    private func container(results: String) throws -> NrdbResultContainer {
        let json = #"{"nrql":"SELECT 1","results":\#(results),"metadata":{"facets":null,"timeWindow":null}}"#
        return try JSONDecoder().decode(NrdbResultContainer.self, from: Data(json.utf8))
    }

    @Test func emptyResultsDoNotCrash() throws {
        let container = try container(results: "[]")

        #expect(container.fieldNames.isEmpty)
        #expect(container.allFacets.isEmpty)
        #expect(container.minDate == nil)
        #expect(container.maxDate == nil)
        #expect(container.dateAdjustment == 0)
    }

    @Test func unsupportedFieldDoesNotDropLaterFields() throws {
        // an array of mixed values isn't decodable; "count" comes after it
        let container = try container(results: #"[{"mixed":[1,"a"],"count":5}]"#)

        #expect(container.data.first?.numberFields["count"] == 5)
        #expect(container.fieldNames == ["count"])
    }

    @Test func fieldNamesAreUniqueAcrossRows() throws {
        let container = try container(results: #"[{"count":1},{"count":2,"average":3}]"#)

        #expect(Set(container.fieldNames) == ["count", "average"])
        #expect(container.fieldNames.count == 2)
    }

    @Test func facetedTimeseriesIdsAreUnique() throws {
        let container = try container(results: """
        [
          {"beginTimeSeconds":100,"endTimeSeconds":160,"facet":"a","count":1},
          {"beginTimeSeconds":100,"endTimeSeconds":160,"facet":"b","count":2}
        ]
        """)

        #expect(Set(container.data.map(\.id)).count == 2)
        #expect(container.allFacets == ["a", "b"])
    }

    @Test func comparisonShiftsPreviousPeriodForward() throws {
        let container = try container(results: """
        [
          {"beginTimeSeconds":1000,"endTimeSeconds":1060,"comparison":"current","count":1},
          {"beginTimeSeconds":400,"endTimeSeconds":460,"comparison":"previous","count":1}
        ]
        """)

        #expect(container.dateAdjustment == 600)
        #expect(container.adjustedTime(Date(timeIntervalSince1970: 400)) == Date(timeIntervalSince1970: 1000))
        #expect(container.comparisonDate(for: container.data[0]) == container.data[0].beginTime)
        #expect(container.comparisonDate(for: container.data[1]) == container.data[0].beginTime)
        #expect(container.data[1].beginTime == Date(timeIntervalSince1970: 400))
    }

    @Test func comparisonTablePairsTimeBucketsAndFacetsRatherThanResultOrder() throws {
        let container = try container(results: """
        [
          {"beginTimeSeconds":1000,"endTimeSeconds":1060,"facet":"a","comparison":"current","count":10},
          {"beginTimeSeconds":1000,"endTimeSeconds":1060,"facet":"b","comparison":"current","count":20},
          {"beginTimeSeconds":1060,"endTimeSeconds":1120,"facet":"a","comparison":"current","count":30},
          {"beginTimeSeconds":460,"endTimeSeconds":520,"facet":"a","comparison":"previous","count":3},
          {"beginTimeSeconds":400,"endTimeSeconds":460,"facet":"b","comparison":"previous","count":2},
          {"beginTimeSeconds":400,"endTimeSeconds":460,"facet":"a","comparison":"previous","count":1}
        ]
        """)
        let table = TableChart(config: ChartConfiguration(resultContainer: container))
        let rows = table.rows

        #expect(rows.count == 3)
        #expect(rows.map { $0.current?.numberFields["count"] } == [10, 20, 30])
        #expect(rows.map { $0.previous?.numberFields["count"] } == [1, 2, 3])
        #expect(rows.map { $0.datum.facet } == ["a", "b", "a"])
    }

    @Test func comparisonTableKeepsUnmatchedBucketsAndMissingFieldsBlank() throws {
        let container = try container(results: """
        [
          {"beginTimeSeconds":1000,"endTimeSeconds":1060,"comparison":"current","count":10},
          {"beginTimeSeconds":1060,"endTimeSeconds":1120,"comparison":"current","count":20},
          {"beginTimeSeconds":400,"endTimeSeconds":460,"comparison":"previous","other":1},
          {"beginTimeSeconds":520,"endTimeSeconds":580,"comparison":"previous","count":3},
          {"beginTimeSeconds":460,"endTimeSeconds":580,"comparison":"previous","count":4}
        ]
        """)
        let table = TableChart(config: ChartConfiguration(resultContainer: container))
        let rows = table.rows

        #expect(rows.count == 4)
        #expect(rows[0].previous?.numberFields["other"] == 1)
        #expect(table.value(for: "count", in: rows[0].previous) == "")
        #expect(rows[1].previous == nil)
        #expect(table.value(for: "count", in: rows[1].previous) == "")
        #expect(rows[2].current == nil)
        #expect(rows[2].previous?.numberFields["count"] == 3)
        // A different bucket width is not a match, even at the same aligned start.
        #expect(rows[3].current == nil)
        #expect(rows[3].previous?.numberFields["count"] == 4)
    }

    @Test func comparisonTableMatchesFullFacetTupleAndPreservesDuplicates() throws {
        let container = try container(results: """
        [
          {"facet":["app","200"],"comparison":"current","count":10},
          {"facet":["app","500"],"comparison":"current","count":20},
          {"facet":["app","200"],"comparison":"current","count":30},
          {"facet":["app","500"],"comparison":"previous","count":2},
          {"facet":["app","200"],"comparison":"previous","count":1},
          {"facet":["other","200"],"comparison":"previous","count":4}
        ]
        """)
        let rows = TableChart(config: ChartConfiguration(resultContainer: container)).rows

        #expect(rows.count == 4)
        #expect(rows.map { $0.current?.numberFields["count"] } == [10, 30, 20, nil])
        #expect(rows.map { $0.previous?.numberFields["count"] } == [1, nil, 2, 4])
        #expect(Set(rows.map(\.id)).count == rows.count)
    }

    @Test func comparisonTableHandlesAggregateAndSinglePeriodResults() throws {
        let aggregate = try container(results: """
        [{"comparison":"previous","count":1},{"comparison":"current","count":2}]
        """)
        let rows = TableChart(config: ChartConfiguration(resultContainer: aggregate)).rows
        #expect(rows.count == 1)
        #expect(rows[0].current?.numberFields["count"] == 2)
        #expect(rows[0].previous?.numberFields["count"] == 1)

        let previousOnly = try container(results: """
        [{"beginTimeSeconds":400,"endTimeSeconds":460,"comparison":"previous","count":1}]
        """)
        let previousRows = TableChart(config: ChartConfiguration(resultContainer: previousOnly)).rows
        #expect(previousRows.count == 1)
        #expect(previousRows[0].current == nil)
        #expect(previousOnly.comparisonDate(for: previousOnly.data[0]) == previousOnly.data[0].beginTime)
    }

    @Test func ordinaryTablesKeepSourceOrderAndDuplicateEventTimestamps() throws {
        let container = try container(results: """
        [{"timestamp":1000,"count":2},{"timestamp":1000,"count":1}]
        """)
        let rows = TableChart(config: ChartConfiguration(resultContainer: container)).rows

        #expect(rows.map { $0.current?.numberFields["count"] } == [2, 1])
        #expect(rows.allSatisfy { $0.previous == nil })
        #expect(Set(rows.map(\.id)).count == 2)
        #expect(container.comparisonDate(for: container.data[0]) == container.data[0].timestamp)
    }

    @Test func chartTypeFallsBackWhenResultsNoLongerSupportIt() throws {
        let single = try container(results: #"[{"count":5}]"#)
        let config = ChartConfiguration(resultContainer: single)
        #expect(config.chartType == .billboard)

        let timeseries = try container(results: #"[{"beginTimeSeconds":100,"endTimeSeconds":160,"count":1}]"#)
        config.updateResults(timeseries)
        #expect(config.chartType == .line)

        // a still-supported choice is kept
        config.chartType = .bar
        config.updateResults(timeseries)
        #expect(config.chartType == .bar)
    }

    @Test func switchesToTableForEventsAndNonNumericData() throws {
        let single = try container(results: #"[{"count":5}]"#)
        let config = ChartConfiguration(resultContainer: single)
        #expect(config.chartType == .billboard)

        let events = try container(results: #"[{"timestamp":1000,"appName":"A","duration":1.5}]"#)
        config.updateResults(events)
        #expect(config.chartType == .table)

        let strings = try container(results: #"[{"appName":"A"}]"#)
        #expect(ChartType.cases(for: strings) == [.table])
    }

    @Test func facetedAttributeEchoedAsStringStillCharts() throws {
        let faceted = try container(results: """
        [{"beginTimeSeconds":100,"endTimeSeconds":160,"facet":"a","name":"a","count":1}]
        """)
        #expect(!faceted.prefersTable)
        #expect(ChartType.cases(for: faceted).contains(.line))

        let multi = try container(results: #"[{"facet":["a","b"],"name":"a","host":"b","count":1}]"#)
        #expect(!multi.prefersTable)

        let unrelated = try container(results: #"[{"facet":"a","name":"a","other":"x","count":1}]"#)
        #expect(unrelated.prefersTable)
    }

    @Test func formatParsesTypeAndAttributes() {
        let format = ChartFormat.parseMetadata("chart: Line\nattributes: smoothed, Points\nfuture: x")

        #expect(format.type == .line)
        #expect(format.attributes == ["smoothed", "points"])
        #expect(ChartFormat.parseMetadata("attributes: smoothed points,lines").attributes == ["smoothed", "points", "lines"])
        #expect(ChartFormat.parseMetadata("attributes:").attributes == [])
    }

    @Test func formatAppliesToTimeseriesConfig() throws {
        let timeseries = try container(results: #"[{"beginTimeSeconds":100,"endTimeSeconds":160,"count":1}]"#)

        // no attributes: defaults stay, type is applied
        var config = ChartConfiguration(resultContainer: timeseries)
        ChartFormat.parseMetadata("chart: bar").apply(to: config)
        #expect(config.chartType == .bar)

        // listed attributes are on, the rest off
        config = ChartConfiguration(resultContainer: timeseries)
        ChartFormat.parseMetadata("chart: line\nattributes: points").apply(to: config)
        #expect(config.timeseries.showDataPoints)
        #expect(!config.timeseries.isSmoothed)
        #expect(!config.timeseries.showLines)

        // neither lines nor points would be invisible
        config = ChartConfiguration(resultContainer: timeseries)
        ChartFormat.parseMetadata("chart: line\nattributes: smoothed").apply(to: config)
        #expect(config.timeseries.showLines)
        #expect(!config.timeseries.showDataPoints)

        // a type the data can't show is ignored
        config = ChartConfiguration(resultContainer: timeseries)
        ChartFormat.parseMetadata("chart: pie").apply(to: config)
        #expect(config.chartType == .line)
    }

    @Test func parameterizedAttributesApplyAndPreserveFieldNames() throws {
        let result = try container(results: #"[{"Count":5,"Response Time":2,"size":3}]"#)
        let config = ChartConfiguration(resultContainer: result)
        let gauge = ChartFormat.parseMetadata("chart: billboard\nattributes: gauge, max(250), style(circularCapacity)")
        gauge.apply(to: config)
        #expect(config.billboard.showGauge)
        #expect(config.billboard.gaugeMax == 250)
        #expect(config.billboard.gaugeStyle == .circularCapacity)
        ChartFormat.parseMetadata("chart: billboard\nattributes: gauge, max(-1)").apply(to: config)
        #expect(config.billboard.gaugeMax == 250)

        ChartFormat.parseMetadata(
            "chart: plot\nattributes: x(Response Time), y(Count), size(), color(), x-log"
        ).apply(to: config)
        #expect(config.plot.xField == "Response Time")
        #expect(config.plot.yField == "Count")
        #expect(config.plot.xLogScale)
        #expect(!config.plot.colorFacets)
        #expect(config.plot.sizeField == nil && config.plot.colorField == nil)
    }

    @Test func billboardAndScatterRespectFacetChangesIncludingAllOff() throws {
        let result = try container(results: """
            [{"facet":"A","Count":1,"Other":3},{"facet":"B","Count":2,"Other":4}]
            """)
        let config = ChartConfiguration(resultContainer: result)
        let billboard = BillboardChart(config: config)
        let scatter = ScatterPlot(config: config)
        config.facets.all[0].isSelected = false
        #expect(Set(billboard.data.compactMap(\.facet)) == ["B"])
        #expect(scatter.filteredData.map(\.facet) == ["B"])
        config.facets.all[1].isSelected = false
        #expect(billboard.data.isEmpty)
        #expect(scatter.filteredData.isEmpty)
        config.facets.all[0].isSelected = true
        config.plot.xField = "Other"
        #expect(scatter.filteredData.first?.x == 3)
    }

    @Test func keysetParsesPerRowAndGroupedShapes() throws {
        let rows = try container(results: #"[{"key":"duration","type":"numeric"},{"key":"name","type":"string"}]"#)
        let fromRows = Attribute.attributes(event: "Transaction", fromKeyset: rows)
        #expect(fromRows.map(\.key) == ["duration", "name"])
        #expect(fromRows.first?.type == "numeric")

        let grouped = try container(results: #"[{"stringKeys":["name"],"numericKeys":["duration","error"],"booleanKeys":["error"],"allKeys":["duration","error","name"]}]"#)
        let fromGroups = Attribute.attributes(event: "Transaction", fromKeyset: grouped)
        #expect(fromGroups.map(\.key) == ["duration", "error", "name"])
        #expect(fromGroups.map(\.type) == ["numeric", "boolean", "string"])
    }
}
