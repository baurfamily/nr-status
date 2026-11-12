//
//  TimeseriesPicker.swift
//  NR Status
//
//  Created by Eric Baur on 4/6/25.
//

import SwiftUI

struct TimePicker : View {
    @Binding var query: QueryBuilder
    
    // toolbars hide picker labels, so show them explicitly
    private func labeled<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        HStack(spacing: 4) {
            Text(title).foregroundStyle(.secondary)
            content().labelsHidden()
        }
    }
    
    var body: some View {
        HStack(spacing: 16) {
            labeled("Since") {
                Picker("Since", selection: $query.timewindow) {
                    ForEach(TimeWindowChoice.choices) { choice in
                        Text(choice.since).tag(choice)
                    }
                }
            }
            Toggle(isOn: $query.defaultCount) {
                Text("Default count")
            }
            Toggle(isOn: $query.isTimeseries) {
                Text("Timeseries")
            }
            if query.isTimeseries {
                labeled("Interval") {
                    Picker("Interval", selection: $query.timeseriesSize) {
                        Text("AUTO").tag(TimeseriesSize.auto)
                        ForEach(TimeIntervalChoice.choices) { choice in
                            Text(choice.displayName).tag(TimeseriesSize.interval(choice))
                        }
                        Text("MAX").tag(TimeseriesSize.max)
                    }
                }
            }
            labeled("Limit") {
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

