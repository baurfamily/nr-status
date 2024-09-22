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
        let query = "query { actor { user { email } } }"
        
        NerdgraphClient(host: host, apiKey: apiKey).query(query) { result in
            callback(result.data?.actor?.user)
        }

    }
    
//    func entities() -> Entities {
//        {
//          actor {
//            entitySearch(queryBuilder: {domain: APM}) {
//              results {
//                entities {
//                  guid
//                  accountId
//                  name
//                }
//              }
//            }
//          }
//        }
//    }
}
