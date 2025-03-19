//
//  AttributeGroup.swift
//  NR Status
//
//  Created by Eric Baur on 3/18/25.
//

import SwiftUI

struct AttributeGroup : View {
    let title: String
    
    @Binding var attributes: [Attribute]
    var filterClosure: ((Attribute) -> Bool)
    
    var filteredAttributes: [Attribute] {
        attributes.filter { filterClosure($0) }
    }
    
    var body : some View {
        Text(title).bold()
        ForEach($attributes, id: \.self) { attribute in
            if filteredAttributes.contains(attribute.wrappedValue) {
                NavigationLink(value: attribute.wrappedValue) {
                    AttributeListView(attribute: attribute.wrappedValue)
                }
                .buttonStyle(.borderless)
            }
        }
    }
}
