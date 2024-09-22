//
//  ContentView.swift
//  NR Status
//
//  Created by Eric Baur on 9/21/24.
//

import SwiftUI

struct ContentView: View {
    @AppStorage("host") var host: String = "api.newrelic.com"
    @AppStorage("apiKey") var apiKey: String = "YOUR_API_KEY"
    
    @State var email: String = ""
    
    var body: some View {
        VStack {
            Form {
                TextField("API Url", text: $host)
                TextField("API Key", text: $apiKey)
                Button("Test") {
                    print("Test: \(host)")
                    testRequest()
                }
            }
            
            Text("API Result")
            Text(email)
        }
        .padding()
    }
    
    func testRequest() {
        let query = "query { actor { accounts { id name } user { email } } }"
        
        NerdgraphClient(host: host, apiKey: apiKey).query(query) { result in
            email = result.data?.actor?.user?.email ?? ""
        }

    }
}

#Preview {
    ContentView()
}
