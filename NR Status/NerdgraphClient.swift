//
//  NerdgraphClient.swift
//  NR Status
//
//  Created by Eric Baur on 9/22/24.
//

import Foundation
import SwiftGraphQLClient
import GraphQL

struct NerdgraphClient {
    private let url: URL
    private let apiKey: String
    
    private var defaultRequest: URLRequest {
        get {
            var request = URLRequest(url: url)

            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue(apiKey, forHTTPHeaderField: "api-key")
            request.httpMethod = "POST"

            return request
        }
    }
    
    init(host: String, apiKey: String) {
        if let url = URL(string:"https://\(host)/graphql") {
            self.url = url
            self.apiKey = apiKey
        } else {
            self.url = URL(string:"https://api.newrelic.com/graphql")!
            self.apiKey = "NRAK-"
        }
    }
    
    
    func rawQuery(_ query: String, variables: [String:Any] = [:], debug: Bool = false, callback: @escaping ([String:Any]) -> ()) {
        var request = defaultRequest

        let json: [String:Any] = ["query": query, "variables": variables ]
        if debug {
            print("request: \(request)")
        }
        guard let data = try? JSONSerialization.data(withJSONObject: json) else { return }

        request.httpBody = data

        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            guard let data = data, error == nil else {
                    print(error?.localizedDescription ?? "No data")
                    return
                }
            let responseJSON = try? JSONSerialization.jsonObject(with: data, options: [])
            
            if let responseJSON = responseJSON as? [String: Any] {
                if debug {
                    print("responseJSON: \(responseJSON)")
                }
                callback(responseJSON)
            }
        }
        task.resume()
    }

    func query(_ query: String, variables: [String:Any] = [:], debug: Bool = false, callback: @escaping (Root) -> ()) {
        var request = defaultRequest

        let json: [String:Any] = ["query": query, "variables": variables ]
        if debug {
            print("request query: \(query)")
            print("request vars: \(variables)")
        }
        guard let data = try? JSONSerialization.data(withJSONObject: json) else { return }

        request.httpBody = data

        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            guard let data = data, error == nil else {
                print(error?.localizedDescription ?? "No data")
                return
            }
            
            if debug {
                print("response data: \(String(decoding: data, as: Unicode.UTF8.self))")
            }

            if let responseObject = try? JSONDecoder().decode(Root.self, from: data) {
                if debug {
                    print("responseObject: \(responseObject)")
                }
                callback(responseObject)
            }
        }
        task.resume()
    }
    
}
