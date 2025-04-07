//
//  AttributeListView.swift
//  NR Status
//
//  Created by Eric Baur on 3/18/25.
//

import SwiftUI

struct AttributeListView : View {
    let attribute: Attribute
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
                        print("popover for \(attribute.key)")
                        Task {
                            self.summaryStats = await AttributeSummary.generate(from: attribute)
                        }
                    }
            }.buttonStyle(.borderless)
            
            Menu {
                Button("Select") { print("select") }
                Button("Facet") { print("facet") }
                Divider()
                Button("Count") { print("count") }
                Button("Count Unique") { print("uniq") }
                Divider()
                Button("Average") { print("avg") }
                Button("Std. Dev.") { print("stddev") }
                Button("Minimum") { print("min") }
                Button("Maximum") { print("max") }
            } label: {
                Image(systemName: "chart.xyaxis.line")
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal)
    }
}
