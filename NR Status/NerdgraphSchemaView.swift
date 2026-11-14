import SwiftUI

struct NerdgraphSchemaView: View {
    let loadID: String
    let load: () async throws -> NerdgraphSchema
    let onInsert: (String) -> Void
    @AppStorage("nerdgraphProfiles", store: NerdgraphConfig.sharedDefaults) private var profileData = Data()
    @State private var schema: NerdgraphSchema?
    @State private var error: String?
    @State private var selectedType = ""
    @State private var search = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("GraphQL Fields").font(.headline)
            if let error {
                Text(error).foregroundStyle(.red).textSelection(.enabled)
            } else if let schema {
                Picker("Type", selection: $selectedType) {
                    ForEach(schema.types.filter { $0.fields != nil }.sorted { $0.name < $1.name }, id: \.name) { type in
                        Text(type.name).tag(type.name)
                    }
                }
                TextField("Find fields and docs", text: $search).textFieldStyle(.roundedBorder)
                ScrollView {
                    VStack(alignment: .leading, spacing: 8) {
                        if let description = schema.type(named: selectedType)?.description {
                            Text(description).font(.caption).textSelection(.enabled)
                        }
                        ForEach(fields(in: schema), id: \.name) { field in
                            DisclosureGroup {
                                Text(field.type.displayName).font(.system(.caption, design: .monospaced))
                                if let description = field.description {
                                    Text(description).font(.caption).textSelection(.enabled)
                                }
                                ForEach(field.args, id: \.name) { argument in
                                    Text("\(argument.name): \(argument.type.displayName)")
                                        .font(.system(.caption, design: .monospaced))
                                    if let description = argument.description {
                                        Text(description).font(.caption).foregroundStyle(.secondary)
                                    }
                                }
                                HStack {
                                    Button("Insert") { onInsert(field.name) }
                                    if let name = field.type.namedType, schema.type(named: name)?.fields != nil {
                                        Button("Browse Type") { selectedType = name }
                                    }
                                }
                                .buttonStyle(.borderless)
                            } label: {
                                Text(field.name).font(.system(.body, design: .monospaced))
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxHeight: 420)
            } else {
                ProgressView("Loading schema...")
            }
        }
        .task(id: loadID + profileData.base64EncodedString()) {
            schema = nil
            error = nil
            do {
                let schema = try await load()
                guard !Task.isCancelled else { return }
                self.schema = schema
                if schema.type(named: selectedType) == nil { selectedType = schema.queryType.name }
            } catch {
                guard !Task.isCancelled else { return }
                self.error = error.localizedDescription
            }
        }
    }

    private func fields(in schema: NerdgraphSchema) -> [NerdgraphSchema.Field] {
        (schema.type(named: selectedType)?.fields ?? []).filter {
            search.isEmpty || $0.name.localizedCaseInsensitiveContains(search)
                || $0.description?.localizedCaseInsensitiveContains(search) == true
        }
    }
}
