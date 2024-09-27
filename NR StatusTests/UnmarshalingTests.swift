//
//  UnmarshalingTests.swift
//  NR Status
//
//  Created by Eric Baur on 9/24/24.
//

import Testing
import Foundation
@testable import NR_Status

// note to self: this is a class to be able to look up the correct bundle
@Suite class UnmarshalingTests {
    func unmarhsal(filename: String) -> Root? {
        guard let path = Bundle(for: UnmarshalingTests.self).path(forResource: filename, ofType: "json") else {
            fatalError("\(filename).json not found")
        }
        let jsonData = try? Data(contentsOf: URL(fileURLWithPath: path))
        
        do {
            if let jsonData = jsonData {
                let responseObject = try JSONDecoder().decode(Root.self, from: jsonData)
                return responseObject
            }
        }
        catch {
            print("decode error ------------- start")
            print(error)
            print("decode error ------------- end")
        }
        return nil
    }
    
    @Test func decodeUserResponse() {
        let root = unmarhsal(filename: "UserResponse")
        #expect(root != nil)
        #expect(root?.data?.actor?.user?.email == "baurfamily@gmail.com")
    }
    
    @Test func decodeEntityResponse() {
        let root = unmarhsal(filename: "EntitySearchResponse_full")
        #expect(root != nil)
        #expect(root?.data?.actor?.entitySearch?.results?.entities?[0].accountId == 265881)
    }
    
    @Test func decodeEntityGrouping() {
        let root = unmarhsal(filename: "EntitySearchResponse_types")
        #expect(root != nil)
        let result = root!.data!.actor!.entitySearch!
        #expect(result.count! == 54)
        #expect(result.types!.count == 15)
        #expect(result.types![0].count! == 17)
        #expect(result.types![0].domain! == .INFRA)
        #expect(result.types![0].entityType! == "AWSLAMBDAREGION")
    }
    
    @Test func decodeApmEntityResponse() {
        let root = unmarhsal(filename: "EntitySearchResponse_apm")
        #expect(root != nil)
        let entity = root!.data!.actor!.entitySearch!.results!.entities![0]
        #expect(entity.accountId == 265881)
        #expect(entity.domain == .APM)
        #expect(entity.entityTypename == "APPLICATION")
    }
    
}
