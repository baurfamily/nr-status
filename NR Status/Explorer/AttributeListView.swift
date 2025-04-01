//
//  AttributeListView.swift
//  NR Status
//
//  Created by Eric Baur on 3/18/25.
//

import SwiftUI

struct AttributeListView : View {
    let attribute: Attribute
    @Binding var query: QueryBuilder
    
    @State private var detailPresented: Bool = false
    @State private var summaryStats: AttributeSummary?
    
    var body : some View {
        HStack {
            Text(attribute.key)
            Spacer()
            
            Button {
                self.detailPresented = true
            } label: {
               Image(systemName: "eye")
            }
            .popover(isPresented: $detailPresented) {
                VStack {
                    if let summaryStats {
                        AttributeSummaryView(summary: summaryStats)
                    }
                }.padding(.all)
                    .task {
                        Task {
                            self.summaryStats = await AttributeSummary.generate(from: attribute)
                        }
                    }
            }.buttonStyle(.borderless)
            
            Menu {
                Button("Select") { addSelect() }
                Button("Facet") { addFacet() }
                Divider()
                Button("Count") { addCount() }
                Button("Count Unique") { addUniqueCount() }
                Divider()
                Button("Average") { addAverage() }
                Button("Std. Dev.") { addStdDev() }
                Button("Minimum") { addMin() }
                Button("Maximum") { addMax() }
            } label: {
                Image(systemName: "chart.xyaxis.line")
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal)
    }
    
    func addSelect() {
        query.attributes.append(attribute)
    }
    
    func addFacet() {
        query.facets.append(attribute)
    }
    
    func addCount() {
//        query..append(attribute)
    }
    
    func addUniqueCount() {
        
    }
    
    func addAverage() {
        
    }
    
    func addStdDev() {
        
    }
    
    func addMin() {
        
    }
    
    func addMax() {
        
    }
}
