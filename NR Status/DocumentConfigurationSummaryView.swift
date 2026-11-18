import SwiftUI

struct DocumentConfigurationSummaryView: View {
    let text: String

    private var summary: Result<[(key: String, value: String)], Error> {
        Result {
            _ = try NrqlConnection.parseDocumentConfig(text)
            return try ConfigurationYAML(text).displayFields
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            switch summary {
            case .success(let fields):
                if fields.isEmpty {
                    Text("Uses the default API key and preferred accounts from Settings.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(Array(fields.enumerated()), id: \.offset) { _, field in
                        LabeledContent {
                            Text(field.value.isEmpty ? "Not set" : field.value)
                                .textSelection(.enabled)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        } label: {
                            Text(field.key).foregroundStyle(.secondary)
                                .frame(width: 110, alignment: .leading)
                        }
                    }
                }
            case .failure(let error):
                Label(error.localizedDescription, systemImage: "exclamationmark.triangle")
                    .foregroundStyle(.red)
                    .textSelection(.enabled)
            }
        }
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityIdentifier("document-configuration-summary")
    }
}
