//
//  NR_StatusTests.swift
//  NR StatusTests
//
//  Created by Eric Baur on 9/21/24.
//

import Testing
import Foundation
@testable import NR_Status

extension NerdgraphClient {
    func query(_ query: String, debug: Bool, completion: @escaping (Root) -> Void) {
        completion(Root(data: .init(actor: .init(user: .init(email: "baur@nerdgraph.com")))))
    }
}

struct NR_StatusTests {

    @Test func example() async throws {
        print("trying to run a query")
        var result : Root?
        NerdgraphClient(host:"localhost", apiKey: "apiKey").query("query { actor { user { email } } }", debug: true) { result = $0 }
        
        #expect(result != nil)
        #expect(result?.data?.actor?.user?.email == "baur@nerdgraph.com")
    }

}
