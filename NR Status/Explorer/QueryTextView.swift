//
//  QueryTextView.swift
//  NR Status
//

import SwiftUI

struct QueryTextView : View {
    let nrql: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Query").font(.headline)
                Spacer()
                Button {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(nrql, forType: .string)
                } label: {
                    Image(systemName: "doc.on.doc")
                }
                .buttonStyle(.borderless)
                .help("Copy query")
            }
            Text(nrql)
                .font(.system(.body, design: .monospaced))
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(8)
                .background(.quaternary, in: RoundedRectangle(cornerRadius: 6))
        }
        .padding(.bottom, 8)
    }
}

#Preview {
    QueryTextView(nrql: "FROM Transaction\nSELECT COUNT(*)\nSINCE 6 hours ago\nFACET name")
        .padding()
        .frame(width: 300)
}
