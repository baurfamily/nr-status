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
        guard let url = URL(string:"https://\(host)/graphql") else { return }
        var request = URLRequest(url: url)
        
        let json = ["query": "query { actor { user { email } } }"
                    ]
        guard let data = try? JSONEncoder().encode(json) else { return }

        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "api-key")
        request.httpMethod = "POST"
        request.httpBody = data
        
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            guard let data = data, error == nil else {
                    print(error?.localizedDescription ?? "No data")
                    return
                }
            
            let responseJSON = try? JSONSerialization.jsonObject(with: data, options: [])
            
            if let responseJSON = responseJSON as? [String: Any] {
                print(responseJSON)
                setEmail(with: responseJSON)
//                var thing: String = responseJSON["actor"]?["user"]?["email"] as? String ?? "No email"
//                    email = "ugh"
            }
            
            
        }
        task.resume()
        
    }
    
    func setEmail(with responseJSON: [String: Any]) {
        guard let data : [String: Any] = responseJSON["data"] as? [ String: Any ] else { return }
        guard let actor : [String: Any] = data["actor"] as? [ String: Any ] else { return }
        guard let user : [String: Any] = actor["user"] as? [ String: Any] else { return }
        guard let useremail : String = user["email"] as? String else { return }
        email = useremail
        
        let emailKeyPath = \JSONSerialization.data.actor.user.email
        let em = responseJSON[emailKeyPath] as? String
        print("key: \(em ?? "nothing")")

    }
}

#Preview {
    ContentView()
}
