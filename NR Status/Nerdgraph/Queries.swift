//
//  Queries.swift
//  NR Status
//
//  Created by Eric Baur on 9/22/24.
//

import Foundation

struct Queries {
    static var host: String {
        return UserDefaults.standard.string(forKey: "host") ?? "https://api.newrelic.com"
    }
    static var apiKey: String {
        return UserDefaults.standard.string(forKey: "apiKey") ?? "NRAK-"
    }
    
    static func user(callback: @escaping (User?) -> Void) {
        let query = "query NRStatus_User { actor { user { email } } }"
        
        NerdgraphClient(host: host, apiKey: apiKey).query(query) { result in
            callback(result.data?.actor?.user)
        }
    }
    
    static func accounts(callback: @escaping ([Account]?) -> Void) {
        let query = "query NRStatus_Accounts { actor { accounts { id name } } }"
        
        NerdgraphClient(host: host, apiKey: apiKey).query(query) { result in
            callback(result.data?.actor?.accounts)
        }
    }
    
    static func entities(domain: Entity.Domain, callback: @escaping ([Entity]?) -> Void) {
        let query = """
            query NRStatus_Entities {
              actor {
                user { email }
                accounts { id name }
                entitySearch(queryBuilder: {domain: \(domain.rawValue)}) {
                  count
                  results {
                    nextCursor
                    entities {
                      guid
                      accountId
                      name
                    }
                  }
                }
              }
            }
        """
        
        NerdgraphClient(host: host, apiKey: apiKey).query(query, debug: true) { result in
            callback(result.data?.actor?.entitySearch?.results?.entities)
        }
    }
}
