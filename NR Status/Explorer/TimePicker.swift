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
    
    var body: some View {
        HStack {
            Picker("TimeWindow", selection: $selectedWindow) {
                ForEach(TimeWindowChoice.choices, id:\.self) { choice in
                    Text(choice.since).tag(choice.nrql)
                }
            }.onChange(of: selectedWindow) { _, newValue in
                query.timewindow = newValue
            }
            Toggle(isOn: $query.isTimeseries) {
                Text("Timeseries")
            }
            if query.isTimeseries {
                Picker("Interval", selection: $query.timeseriesSize) {
                    Text("AUTO").tag("AUTO")
                    ForEach(TimeIntervalChoice.choices) { choice in
                        Text(choice.displayName).tag(choice.displayName)
                    }
                    Text("MAX").tag("MAX")
                }
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

