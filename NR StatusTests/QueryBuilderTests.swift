//
//  QueryBuilderTests.swift
//  NR StatusTests
//

import Testing
import Foundation
@testable import NR_Status

struct QueryBuilderTests {
    let duration = Attribute(event: "Transaction", type: "numeric", key: "duration")
    let name = Attribute(event: "Transaction", type: "string", key: "name")

    @Test func defaultQueryCountsEverything() {
        let query = QueryBuilder(event: "Transaction")
        #expect(query.nrql == "FROM Transaction SELECT COUNT(*) SINCE 6 hours ago")
    }

    @Test func defaultCountCanBeDisabled() {
        var query = QueryBuilder(event: "Transaction")
        query.defaultCount = false
        #expect(query.nrql == "FROM Transaction SELECT * SINCE 6 hours ago")
    }

    @Test func selectsAttributes() {
        var query = QueryBuilder(event: "Transaction")
        query.add(attribute: duration)
        query.add(attribute: name)
        #expect(query.nrql == "FROM Transaction SELECT duration, name SINCE 6 hours ago")
    }

    @Test func attributesAndAggregatesAreCombined() {
        var query = QueryBuilder(event: "Transaction")
        query.add(attribute: name)
        query.add(aggregate: "average", with: duration)
        #expect(query.nrql == "FROM Transaction SELECT name, average(duration) SINCE 6 hours ago")
    }

    @Test func facetReplacesAttributesAndPreviousFacet() {
        var query = QueryBuilder(event: "Transaction")
        query.add(attribute: duration)
        query.add(facet: duration)
        query.add(facet: name)

        #expect(query.attributes.isEmpty)
        #expect(query.facets == [name])
        #expect(query.nrql == "FROM Transaction SELECT COUNT(*) SINCE 6 hours ago FACET name")
    }

    @Test func containsAndRemoveMatchByKey() {
        var query = QueryBuilder(event: "Transaction")
        query.add(facet: name)
        query.add(attribute: duration)
        query.add(aggregate: "max", with: duration)

        #expect(query.contains(attribute: duration))
        #expect(query.contains(aggregate: "max", with: duration))
        #expect(!query.contains(aggregate: "min", with: duration))
        #expect(query.contains(facet: name))

        query.remove(attribute: duration)
        query.remove(aggregate: "max", with: duration)
        query.remove(facet: name)

        #expect(!query.contains(attribute: duration))
        #expect(!query.contains(aggregate: "max", with: duration))
        #expect(!query.contains(facet: name))
    }

    @Test func allowsAggregatesOnlyWithoutPlainAttributesOrWhenFaceted() {
        var query = QueryBuilder(event: "Transaction")
        #expect(query.allowsAggregates)

        query.add(attribute: duration)
        #expect(!query.allowsAggregates)

        query.add(facet: name)
        #expect(query.allowsAggregates)
    }

    @Test func timeWindowIsConfigurable() {
        var query = QueryBuilder(event: "Transaction")
        query.timewindow = TimeWindowChoice(since: "1 day ago")
        #expect(query.nrql == "FROM Transaction SELECT COUNT(*) SINCE 1 day ago")
    }

    @Test func limitClause() {
        var query = QueryBuilder(event: "Transaction")

        query.limit = .count(100)
        #expect(query.nrql.hasSuffix(" LIMIT 100"))

        query.limit = .max
        #expect(query.nrql.hasSuffix(" LIMIT MAX"))

        query.limit = .auto
        #expect(!query.nrql.contains("LIMIT"))
    }

    @Test func formattedQueryPutsEachClauseOnItsOwnLine() {
        var query = QueryBuilder(event: "Transaction")
        query.add(aggregate: "average", with: duration)
        query.add(facet: name)
        query.isTimeseries = true

        #expect(query.formattedNrql == """
        FROM Transaction
        SELECT average(duration)
        SINCE 6 hours ago
        FACET name
        TIMESERIES AUTO
        """)
        #expect(query.formattedNrql.replacingOccurrences(of: "\n", with: " ") == query.nrql)
    }

    @Test func timeseriesIsCombinedWithLimit() {
        var query = QueryBuilder(event: "Transaction")
        query.isTimeseries = true

        #expect(query.nrql == "FROM Transaction SELECT COUNT(*) SINCE 6 hours ago TIMESERIES AUTO")

        query.limit = .count(10)
        #expect(query.nrql == "FROM Transaction SELECT COUNT(*) SINCE 6 hours ago LIMIT 10 TIMESERIES AUTO")

        query.timeseriesSize = .interval(TimeIntervalChoice.choices[1])
        #expect(query.nrql.hasSuffix(" TIMESERIES 5 minutes"))

        query.timeseriesSize = .max
        #expect(query.nrql.hasSuffix(" TIMESERIES MAX"))
    }
}
