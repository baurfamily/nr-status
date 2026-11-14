import SwiftUI

@MainActor @Observable
final class NerdgraphDocumentation {
    struct Cursor: Equatable {
        let cellID: UUID
        let text: String
        let location: Int
    }

    struct Source {
        let cursor: Cursor
        let loadID: String
        let load: () async throws -> NerdgraphSchema
        let onInsert: (String) -> Void
    }

    static let shared = NerdgraphDocumentation()
    var source: Source?

    func clear(cellID: UUID) {
        if source?.cursor.cellID == cellID { source = nil }
    }
}

struct NerdgraphSchemaView: View {
    let documentation: NerdgraphDocumentation
    @AppStorage("nerdgraphProfiles", store: NerdgraphConfig.sharedDefaults) private var profileData = Data()
    @State private var schema: NerdgraphSchema?
    @State private var error: String?
    @State private var selectedTarget: NerdgraphSchema.DocumentationTarget?
    @State private var search = ""

    var body: some View {
        Group {
            if documentation.source == nil {
                Text("Focus a GraphQL cell to browse its documentation.")
                    .foregroundStyle(.secondary)
            } else if let error {
                Text(error).foregroundStyle(.red).textSelection(.enabled).padding()
            } else if let schema {
                NavigationSplitView {
                    VStack(alignment: .leading, spacing: 8) {
                        TextField("Search all types, fields, and docs", text: $search)
                            .textFieldStyle(.roundedBorder)
                            .padding([.top, .horizontal])
                        List(schema.documentationMatches(search), selection: $selectedTarget) { target in
                            Text(target.title).tag(target)
                        }
                    }
                    .navigationSplitViewColumnWidth(min: 200, ideal: 260, max: 400)
                } detail: {
                    documentationDetail(in: schema)
                }
            } else {
                ProgressView("Loading schema...")
            }
        }
        .frame(minWidth: 600, minHeight: 400)
        .navigationTitle("Nerdgraph Documentation")
        .task(id: (documentation.source?.loadID ?? "") + profileData.base64EncodedString()) {
            schema = nil
            error = nil
            guard let source = documentation.source else { selectedTarget = nil; return }
            do {
                let schema = try await source.load()
                guard !Task.isCancelled else { return }
                self.schema = schema
                followCursor(in: schema)
            } catch {
                guard !Task.isCancelled else { return }
                self.error = error.localizedDescription
            }
        }
        .onChange(of: documentation.source?.cursor) {
            if let schema { followCursor(in: schema) }
        }
    }

    private func followCursor(in schema: NerdgraphSchema) {
        guard let cursor = documentation.source?.cursor else { return }
        selectedTarget = NerdgraphCompletion.documentationTarget(text: cursor.text, location: cursor.location, schema: schema)
            ?? NerdgraphSchema.DocumentationTarget(typeName: schema.queryType.name)
    }

    @ViewBuilder private func documentationDetail(in schema: NerdgraphSchema) -> some View {
        if let type = schema.type(named: selectedTarget?.typeName) {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        Text(type.name).font(.title2.bold()).id("type." + type.name)
                        Text(type.kind).font(.caption).foregroundStyle(.secondary)
                        if let description = type.description { Text(description).textSelection(.enabled) }
                        ForEach(type.fields ?? [], id: \.name) { field in
                            fieldDocumentation(field, schema: schema).id(field.name)
                        }
                        ForEach(type.inputFields ?? [], id: \.name) { field in
                            argumentDocumentation(field).id(field.name)
                        }
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .onChange(of: selectedTarget, initial: true) {
                    proxy.scrollTo(selectedTarget?.anchor ?? "type." + type.name, anchor: .top)
                }
            }
        } else {
            Text("Select a type or field.").foregroundStyle(.secondary)
        }
    }

    private func fieldDocumentation(_ field: NerdgraphSchema.Field, schema: NerdgraphSchema) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("\(field.name): \(field.type.displayName)")
                .font(.system(.headline, design: .monospaced))
                .foregroundStyle(selectedTarget?.fieldName == field.name ? Color.accentColor : Color.primary)
            if let description = field.description { Text(description).textSelection(.enabled) }
            ForEach(field.args, id: \.name) { argument in
                argumentDocumentation(argument).id(field.name + "." + argument.name)
            }
            HStack {
                if let source = documentation.source {
                    Button("Insert Field") { source.onInsert(field.name) }
                }
                if let name = field.type.namedType, schema.type(named: name) != nil {
                    Button("Browse \(name)") { selectedTarget = .init(typeName: name) }
                }
            }
            .buttonStyle(.borderless)
            Divider()
        }
    }

    private func argumentDocumentation(_ argument: NerdgraphSchema.Argument) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("\(argument.name): \(argument.type.displayName)")
                .font(.system(.body, design: .monospaced))
            if let description = argument.description {
                Text(description).font(.callout).foregroundStyle(.secondary).textSelection(.enabled)
            }
            if let value = argument.defaultValue { Text("Default: \(value)").font(.caption) }
        }
    }
}
