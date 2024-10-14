//
//  Queries.swift
//  NR Status
//
//  Created by Eric Baur on 9/22/24.
//

import Foundation

struct Queries {
    var _host: String?
    var host: String {
        guard _host == nil else { return _host! }
        return UserDefaults.standard.string(forKey: "host") ?? "api.newrelic.com"
    }
    
    var _apiKey: String?
    var apiKey: String {
        guard _apiKey == nil else { return _apiKey! }
        return UserDefaults.standard.string(forKey: "apiKey") ?? "NRAK-"
    }
    
    var _accountIds: String?
    var accountIds: String {
        guard _accountIds == nil else { return _accountIds! }
        return UserDefaults.standard.string(forKey: "accountIds") ?? ""
    }
    
    init(host: String? = nil, apiKey: String? = nil, accountIds: String? = nil) {
        self._host = host
        self._apiKey = apiKey
        self._accountIds = accountIds
    }
    
    func user(debug: Bool = false, _ callback: @escaping (User?) -> Void) {
        let query = "query NRStatus_User { actor { user { email } } }"
        
        NerdgraphClient(host: host, apiKey: apiKey).query(query, debug: debug) { result in
            callback(result.data?.actor?.user)
        }
    }
    
    func accounts(debug: Bool = false, _ callback: @escaping ([Account]?) -> Void) {
        let query = "query NRStatus_Accounts { actor { accounts { id name } } }"
        
        NerdgraphClient(host: host, apiKey: apiKey).query(query, debug: debug) { result in
            callback(result.data?.actor?.accounts)
        }
    }
    
    func getNrqlData(query nrql: String, debug: Bool = false) async -> NrdbResultContainer? {
        let query = """
        query NRStatus_Nrql($nrql: Nrql!) {
            actor {
                user { email name }
                nrql(accounts: [\(accountIds)], query: $nrql) {
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
        let variables = ["nrql": nrql]
        
        let result = await NerdgraphClient(host: host, apiKey: apiKey).getData(query: query, variables: variables, debug: debug)
        return result?.data?.actor?.nrql
    }
    
    func nrql(query nrql: String, debug: Bool = false, _ callback: @escaping (NrdbResultContainer?) -> Void) {
        let query = """
        query NRStatus_Nrql($nrql: Nrql!) {
            actor {
                user { email name }
                nrql(accounts: [\(accountIds)], query: $nrql) {
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
        let variables = ["nrql": nrql]
        
        NerdgraphClient(host: host, apiKey: apiKey).query(query, variables: variables, debug: debug) { result in
            callback(result.data?.actor?.nrql)
        }
    }
    /*
     }
     */
    //"variables":{"cursor":null,"includeCount":true,"includeResults":true,"includeSummaryMetrics":false,"includeTags":false,"limit":300,"sortType":["REPORTING","ALERT_SEVERITY","NAME"],"nrql":"(alertable IS TRUE AND accountId = '265881' AND (domain = 'APM' AND type = 'APPLICATION'))"}}

    func entities(domain: Entity.Domain, debug: Bool = false, _ callback: @escaping ([Entity]?) -> Void) {
        let query = """
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
        
        let variables : [String:Any]  = [
            "sortType": ["REPORTING","ALERT_SEVERITY","NAME"],
            "nrql": "(alertable IS TRUE AND accountId IN ( \(accountIds) ) AND domain = '\(domain.rawValue)')"
        ]
        
        NerdgraphClient(host: host, apiKey: apiKey).query(query, variables: variables, debug: debug) { result in
            callback(result.data?.actor?.entitySearch?.results?.entities)
        }
    }
}
