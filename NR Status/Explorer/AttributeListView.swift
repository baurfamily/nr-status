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
                        self.summaryStats = await AttributeSummary.generate(from: attribute)
                    }
            }.buttonStyle(.borderless)
            
            Menu {
                Button("Select") { }
                Button("Facet") { }
                Divider()
                Button("Count") { }
                Button("Count Unique") { }
                Divider()
                Button("Average") { }
                Button("Std. Dev.") { }
                Button("Minimum") { }
                Button("Maximum") { }
            } label: {
                Image(systemName: "chart.xyaxis.line")
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal)
    }
}
