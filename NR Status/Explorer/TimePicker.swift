//
//  TimeseriesPicker.swift
//  NR Status
//
//  Created by Eric Baur on 4/6/25.
//

import SwiftUI

struct TimePicker : View {
    @Binding var query: QueryBuilder
    
    var body: some View {
        HStack {
            Picker("TimeWindow", selection: $query.timewindow) {
                ForEach(TimeWindowChoice.choices) { choice in
                    Text(choice.since).tag(choice)
                }
            }
            Toggle(isOn: $query.defaultCount) {
                Text("Default w/Count")
            }
            Toggle(isOn: $query.isTimeseries) {
                Text("Timeseries")
            }
            if query.isTimeseries {
                Picker("Interval", selection: $query.timeseriesSize) {
                    Text("AUTO").tag(TimeseriesSize.auto)
                    ForEach(TimeIntervalChoice.choices) { choice in
                        Text(choice.displayName).tag(TimeseriesSize.interval(choice))
                    }
                    Text("MAX").tag(TimeseriesSize.max)
                }
            } else {
                Picker("Limit", selection: $query.limit) {
                    ForEach(ResultLimit.choices, id: \.self) { choice in
                        Text(choice.displayName).tag(choice)
                    }
                }
            }
        }
    }
}

#Preview {
    @Previewable @State var query: QueryBuilder = .init(event:"Transaction")
    TimePicker(query: $query)
}

