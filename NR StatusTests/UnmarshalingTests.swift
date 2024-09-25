//
//  UnmarshalingTests.swift
//  NR Status
//
//  Created by Eric Baur on 9/24/24.
//

import Testing
import Foundation
@testable import NR_Status

@Suite class UnmarshalingTests {
    func unmarhsal(filename: String) -> Root? {
        guard let path = Bundle(for: UnmarshalingTests.self).path(forResource: filename, ofType: "json") else {
            fatalError("\(filename).json not found")
        }
        let jsonData = try? Data(contentsOf: URL(fileURLWithPath: path))
        
        if let jsonData = jsonData, let responseObject = try? JSONDecoder().decode(Root.self, from: jsonData) {
            return responseObject
        }
        return nil
    }
    
    @Test func decodeUserResponse() {
        let root = unmarhsal(filename: "UserResponse")
        #expect(root != nil)
        #expect(root?.data?.actor?.user?.email == "baurfamily@gmail.com")
    }
    
    @Test func decodeEntityResponse() {
        let root = unmarhsal(filename: "EntitySearchResponse")
        #expect(root != nil)
        #expect(root?.data?.actor?.entitySearch?.results?.entities?[0].name == "Baur Family")
    }
}
