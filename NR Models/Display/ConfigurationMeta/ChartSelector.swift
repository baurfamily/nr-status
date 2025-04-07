//
//  ChartSelector.swift
//  NR Status
//
//  Created by Eric Baur on 3/4/25.
//

import SwiftUI

struct ChartSelector: View {
    var availableChartTypes: [ChartType]
    @Binding var selectedChartType: ChartType?
    
    var body: some View {
        Menu {
            ForEach(ChartType.allCases, id: \.self) { option in
                // The keyboard shortcuts only work if the drop down is focused
                // There might be a way to move this to a top-level menu to make
                // it more global, but I'll lave that for later
                if availableChartTypes.contains(option) {
                    Button(action: { selectedChartType = option }) {
                        Text(option.rawValue)
                    }
                    .keyboardShortcut(option.shortcut)
                } else {
                    Button(action: {}) {
                        Text(option.rawValue).foregroundColor(.gray)
                    }
                    .disabled(true)
                    .keyboardShortcut(option.shortcut)
                }
            }
        } label: {
            Text(selectedChartType?.rawValue ?? "Select chart style...")
                .foregroundColor(.primary)
                .padding(.horizontal)
        }
        .padding(.horizontal)
    }
}
