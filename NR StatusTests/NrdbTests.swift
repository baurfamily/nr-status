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
}
