//
//  PreferencesView.swift
//  NR Status
//
//  Created by Eric Baur on 9/22/24.
//

import SwiftUI

struct PreferencesView: View {
    @AppStorage("host") var host: String = "api.newrelic.com"
    @AppStorage("apiKey") var apiKey: String = "YOUR_API_KEY"
    @AppStorage("accountIds") var accountIds: String = ""
    
    @State var emailCheck: Bool? = nil
    @State var email: String = ""
    @State var accountsCheck: Bool? = nil
    @State var accountNames: String = ""
    
    var body: some View {
        VStack {
            Form {
                TextField("API Url", text: $host)
                TextField("API Key", text: $apiKey)
                TextField("Account IDs (CSV)", text: $accountIds)
                Button("Test") {
                    print("Test: \(host)")
                    testRequest()
                }
            }
            
            Text("API Result")
            Text(email)
            
            List {
                TestPanelView(name: "User", success: $emailCheck, description: $email)
                TestPanelView(name: "Accounts", success: $accountsCheck, description: $accountNames)
            }
        }
        .padding()
    }
    
    func testRequest() {
        Queries.user() { user in
            if let email = user?.email {
                self.email = email
                self.emailCheck = true
            } else {
                self.emailCheck = false
            }
        }
        Queries.accounts() { accounts in
            if let accounts = accounts {
                let names = accounts.map() { "\($0.name ?? "no name found") (\(String($0.id ?? 0)))" }
                let ids = accounts.map() { $0.id }
                
                self.accountNames = names.joined(separator: ", ")
                
                let remoteSet = Set(ids)
                let configSet = Set(accountIds.components(separatedBy: ",").map() {Int($0)} )
                let intersection = remoteSet.intersection(configSet)
                
                self.accountsCheck = !intersection.isEmpty
            } else {
                self.accountsCheck = false
            }
        }
    }
}

struct TestPanelView: View {
    var name: String = ""
    
    @Binding var success: Bool?
    @Binding var description: String
    
    var systemName: String {
        if success == nil {
            return "questionmark"
        } else if success! {
            return "checkmark"
        } else {
            return "xmark"
        }
    }
    var color: Color {
        if success == nil {
            return .white
        } else if success! {
            return .green
        } else {
            return .red
        }
    }
    
    var body : some View {
        HStack {
            Image(systemName: systemName)
                .fontWidth(.expanded)
                .font(.system(size: 25))
                .background(in: RoundedRectangle(cornerRadius: 10))
                .shadow(radius: 5)
                .backgroundStyle(color)
                .fontWeight(.bold)
            
            
            Text(name)
            Text(description)
        }
    }
}

#Preview {
    ContentView()
}
