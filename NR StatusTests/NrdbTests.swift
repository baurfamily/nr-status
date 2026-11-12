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
        let format = ChartFormat.parse(from: "/***\nchart: Line\nattributes: smoothed, Points\nfuture: x\n***/\nSELECT 1")

        #expect(format?.type == .line)
        #expect(format?.attributes == ["smoothed", "points"])
        #expect(ChartFormat.parse(from: "/***\nattributes: smoothed points,lines\n***/")?.attributes == ["smoothed", "points", "lines"])
        #expect(ChartFormat.parse(from: "SELECT 1") == nil)
        #expect(ChartFormat.strip(from: "/***\nchart: line\n***/\nSELECT 1") == "\nSELECT 1")
    }

    @Test func formatAppliesToTimeseriesConfig() throws {
        let timeseries = try container(results: #"[{"beginTimeSeconds":100,"endTimeSeconds":160,"count":1}]"#)

        // no attributes: defaults stay, type is applied
        var config = ChartConfiguration(resultContainer: timeseries)
        ChartFormat.parse(from: "/***\nchart: bar\n***/")?.apply(to: config)
        #expect(config.chartType == .bar)

        // listed attributes are on, the rest off
        config = ChartConfiguration(resultContainer: timeseries)
        ChartFormat.parse(from: "/***\nchart: line\nattributes: points\n***/")?.apply(to: config)
        #expect(config.timeseries.showDataPoints)
        #expect(!config.timeseries.isSmoothed)
        #expect(!config.timeseries.showLines)

        // neither lines nor points would be invisible
        config = ChartConfiguration(resultContainer: timeseries)
        ChartFormat.parse(from: "/***\nchart: line\nattributes: smoothed\n***/")?.apply(to: config)
        #expect(config.timeseries.showLines)
        #expect(!config.timeseries.showDataPoints)

        // a type the data can't show is ignored
        config = ChartConfiguration(resultContainer: timeseries)
        ChartFormat.parse(from: "/***\nchart: pie\n***/")?.apply(to: config)
        #expect(config.chartType == .line)
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
