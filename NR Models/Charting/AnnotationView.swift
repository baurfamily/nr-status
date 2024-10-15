//
//  ChartViews.swift
//  NR Status
//
//  Created by Eric Baur on 10/13/24.
//

import SwiftUI

struct AnnotationView : View {
    var datum: NrdbResults.Datum
    var date: Date
    
    init(for datum: NrdbResults.Datum, on date: Date) {
        self.datum = datum
        self.date = date
    }
    
    var body: some View {
        Text(date.description)
    }
}

#Preview {
    let resultContainer = ChartSamples.sampleData()
    if let datum = resultContainer?.results.data.first {
        GroupBox {
            AnnotationView(
                for: datum,
                on: datum.beginTime!
            )
        }
    }
}
