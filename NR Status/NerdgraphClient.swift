//
//  NerdgraphClient.swift
//  NR Status
//
//  Created by Eric Baur on 9/22/24.
//

import Foundation
import SwiftGraphQLClient
import GraphQL

struct User {
    var email: String
}

struct Actor {
    var user: User
}

struct NerdgraphClient {
    private var client: SwiftGraphQLClient.Client
    
    init(host: String, apiKey: String) {
        let url = URL(string: "https://api.newrelic.com/grpahql")!
        var request = URLRequest(url: url)

        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "api-key")
        request.httpMethod = "POST"

        let config = ClientConfiguration()
        self.client = SwiftGraphQLClient.Client(
            // Default request used to send HTTP requests.
            request: URLRequest(url: url),
//            exchanges: [
//                DedupExchange(),
//                CacheExchange(),
//                FetchExchange()
//            ],
            config: config
        )
    }
    
    func query() {
        print("query?")
        let args = ExecutionArgs(
            query: """
            query ApiTest {
                actor { user { email } }
            }
            """,
            variables: [:]
        )
        
        print("running query")
        client.query(args)
            .sink { completion in
                print("query completed....")
                print(completion)
            } receiveValue: { result in
                print("received value...")
                print(result)
            }
        
    }
    
    func structuredQuery() {
        let query = Selection.
        let query = Selection.Query<[Human]> {
            try $0.friends(selection: human.list)
        }
    }
}
