//
//  GraphQLDocuments.swift
//  NR Status
//

enum GraphQLDocuments {
    static let user = "query NRStatus_User { actor { user { email } } }"

    static let accounts = "query NRStatus_Accounts { actor { accounts { id name } } }"

    static let nrql = """
    query NRStatus_Nrql($accountIds: [Int!]!, $nrql: Nrql!) {
        actor {
            user { email name }
            nrql(accounts: $accountIds, query: $nrql) {
                nrql
                results
                metadata {
                    facets
                    eventTypes
                    timeWindow {
                        begin
                        end
                        since
                        until
                    }
                }
            }
        }
    }
    """

    // just enough to render an application/monitor list
    static let basicEntitySearch = """
    query NRStatus_EntitySearch(
        $nrql: String,
        $sortType: [EntitySearchSortCriteria] = null
    ) {
        actor {
            entitySearch(query: $nrql, sortBy: $sortType, options: {limit: 500}) {
                results {
                    entities {
                        guid
                        accountId
                        domain
                        type
                        name
                        reporting
                        account {
                            id
                            name
                        }
                        ... on AlertableEntityOutline {
                            alertSeverity
                        }
                    }
                    nextCursor
                }
                count
            }
        }
    }
    """

    static let fullEntitySearch = """
    query NRStatus_EntitySearch(
        $cursor: String = null,
        $includeCount: Boolean = false,
        $includeResults: Boolean = true,
        $includeSummaryMetrics: Boolean = true,
        $includeTags: Boolean = false,
        $limit: Int = 500,
        $nrql: String,
        $sortType: [EntitySearchSortCriteria] = null
    ) {
        actor {
            entitySearch(query: $nrql, sortBy: $sortType, options: {limit: $limit}) {
                results(cursor: $cursor) @include(if: $includeResults) {
                    entities {
                        ...EntityInfo
                        ...EntityTags @include(if: $includeTags)
                        ...SummaryMetrics @include(if: $includeSummaryMetrics)
                        ...EntityFragmentExtension
                        guid
                    }
                    nextCursor
                    ...SummaryMetricDefinitions @include(if: $includeSummaryMetrics)
                }
                count
                types @include(if: $includeCount) {
                    count
                    domain
                    type
                }
            }
        }
    }

    fragment EntityInfo on EntityOutline {
        guid
        accountId
        domain
        type
        name
        reporting
        account {
            id
            name
        }
        ... on AlertableEntityOutline {
            alertSeverity
        }
    }

    fragment EntityTags on EntityOutline {
        guid
        tags {
            key
            values
        }
    }

    fragment SummaryMetricDefinitions on EntitySearchResult {
        entityTypes {
            domain
            type
            summaryMetricDefinitions {
                name
                title
                unit
            }
            id
        }
    }

    fragment SummaryMetrics on EntityOutline {
        guid
        summaryMetrics {
            value {
                ... on EntitySummaryNumericMetricValue {
                    numericValue
                }
                ... on EntitySummaryStringMetricValue {
                    stringValue
                }
            }
        }
    }

    fragment EntityFragmentExtension on EntityOutline {
        summaryMetrics {
            name
            title
            value {
                unit
                ... on EntitySummaryMetricValue {
                    unit
                }
                ... on EntitySummaryNumericMetricValue {
                    numericValue
                    unit
                }
                ... on EntitySummaryStringMetricValue {
                    stringValue
                    unit
                }
            }
        }
        ... on DashboardEntityOutline {
            owner {
                email
                userId
            }
            permissions
            dashboardParentGuid
            guid
        }
        guid
    }
    """
}
