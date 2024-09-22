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
        Queries.user() { user in
            if let email = user?.email {
                self.email = email
            }
        }
        
        Queries.entities(domain: .APM) { entities in
            print("--------")
            print("entities")
            print(entities?.count)
            print(entities?.first?.name)
            print(entities)
            print("--------")
        }
    }
}

#Preview {
    ContentView()
}
