//
//  AttributeSelector.swift
//  NR Status
//
//  Created by Eric Baur on 3/15/25.
//

import SwiftUI

struct AttributeSelector : View {
    @Binding var attributes: [Attribute]
    
    struct AttributeGroup : View {
        let title: String
        @Binding var attributes: [Attribute]
        var filterClosure: ((Attribute) -> Bool)
        
        var body : some View {
            DisclosureGroup("\(title) Attributes") {
                ForEach($attributes, id: \.self) { attribute in
                    if filterClosure(attribute.wrappedValue) {
                        Toggle(isOn: attribute.isSelected) {
                            HStack {
                                Text(attribute.wrappedValue.key)
                            }
                        }
                    }
                }
            }
        }
    }
    
    var attributeTypes: [String] { Array(Set(attributes.map(\.type))).sorted() }
    
    var body: some View {
        ForEach(attributeTypes, id: \.self) { typeName in
            AttributeGroup(title: typeName.capitalized, attributes: $attributes) { $0.type == typeName }
        }
    }
}
