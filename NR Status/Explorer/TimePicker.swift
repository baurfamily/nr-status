//
//  TimeseriesPicker.swift
//  NR Status
//
//  Created by Eric Baur on 4/6/25.
//

import SwiftUI

struct TimePicker : View {
    @Binding var query: QueryBuilder
    
    @State var selectedWindow: String = "SINCE 1 hour ago"
    
    var choices: [String] {
        ["SINCE 1 hour ago", "SINCE 6 hours ago", "SINCE 1 day ago", "SINCE 3 days ago", "SINCE 1 week ago", "SINCE 1 month ago"]
    }
    
    var body: some View {
        HStack {
            Toggle(isOn: $query.isTimeseries) {
                Text("Timeseries")
            }
            Picker("TimeWindow", selection: $selectedWindow) {
                ForEach(choices, id:\.self) { choice in
                    Text(choice).tag(choice)
                }
            }.onChange(of: selectedWindow) { _, newValue in
                query.timewindow = newValue
            }
        }.task {
            self.selectedWindow = query.timewindow
        }
    }
}

#Preview {
    @Previewable @State var query: QueryBuilder = .init(event:"Transaction")
    TimePicker(query: $query)
}

