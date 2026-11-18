//
//  QueryBuilderView.swift
//  NR Status
//
//  Created by Eric Baur on 3/08/25.
//

import SwiftUI
import CodeEditorView

extension EnvironmentValues {
    @Entry var queryBuilderConfig: NerdgraphConfig? = nil
}

struct QueryBuilderView : View {
    @State var query = NrqlQuery(from: "SELECT COUNT(*) FROM Transaction FACET name")
    @State var queryBuilder: QueryBuilder = .init(event: "")
    @State private var selectedEvent: String?
    @State private var selectedAccountID: Int?
    @State private var defaultConfig = NerdgraphConfig.current
    @AppStorage("nerdgraphProfiles", store: NerdgraphConfig.sharedDefaults) private var profileSettingsData = Data()
    
    @State var chartConfiguration: ChartConfiguration = ChartConfiguration(resultContainer: NrdbResultContainer.empty)

    @Environment(\.colorScheme) private var colorScheme: ColorScheme

    private struct Request: Hashable {
        let nrql: String
        let config: NerdgraphConfig
    }

    private var config: NerdgraphConfig {
        var config = defaultConfig
        if let selectedAccountID { config.accountIds = String(selectedAccountID) }
        return config
    }

    private var request: Request { Request(nrql: queryBuilder.nrql, config: config) }
    
    var body: some View {
        NavigationSplitView {
            EventExplorer(selection: $selectedEvent)
        } content: {
            Group {
                if let selectedEvent {
                    NavigationStack {
                        AttributeExplorer(event: selectedEvent, query: $queryBuilder)
                            .navigationDestination(for: Attribute.self) {
                                AttributeSummaryActionsView(attribute: $0, query: $queryBuilder)
                            }
                    }
                    .id(selectedEvent)
                    .id(config)
                } else {
                    Text("Select an event").foregroundStyle(.secondary)
                }
            }
            .navigationSplitViewColumnWidth(min: 300, ideal: 380, max: 700)
        } detail: {
            ConfigurableChartView(config: chartConfiguration)
                .inspectorHeader {
                    QueryTextView(nrql: queryBuilder.formattedNrql)
                    if queryBuilder.facets.count == 1, !chartConfiguration.facets.all.isEmpty {
                        Button("Filter Query to Selected Facets") {
                            queryBuilder.filterFacetValues(chartConfiguration.facets.selected)
                        }
                        .disabled(chartConfiguration.facets.selected.isEmpty
                            || chartConfiguration.facets.selected.count == chartConfiguration.facets.all.count)
                        .help("Add a WHERE clause and rerun the query with the selected facet values")
                    }
                }
                .overlay {
                    if query.isRunning {
                        ProgressView()
                    }
                }
                .toolbar {
                    ToolbarItem {
                        Picker("Account", selection: $selectedAccountID) {
                            Text("Default (all preferred accounts)").tag(Int?.none)
                            ForEach(defaultConfig.accountIdList, id: \.self) { id in
                                Text(String(id)).tag(Optional(id))
                            }
                        }
                        .accessibilityIdentifier("query-builder-account-picker")
                        .help("Choose an account for event discovery, attribute details, and chart queries. Manage preferred accounts in Settings.")
                    }
                    ToolbarItemGroup {
                        TimePicker(query: $queryBuilder)
                            .fixedSize()
                    }
                }
        }
        .navigationSplitViewStyle(.balanced)
        .environment(\.queryBuilderConfig, config)
        .focusedSceneValue(\.query, $query)
        .onChange(of: profileSettingsData) {
            defaultConfig = .current
            if let selectedAccountID, !defaultConfig.accountIdList.contains(selectedAccountID) {
                self.selectedAccountID = nil
            }
        }
        .onChange(of: config) {
            chartConfiguration.updateResults(.empty)
        }
        .onChange(of: selectedEvent) {
            if selectedEvent == nil { queryBuilder.event = "" }
        }
        .task(id: request) {
            let request = request
            let newQuery = NrqlQuery(from: request.nrql)
            query = newQuery
            guard !queryBuilder.event.isEmpty else {
                chartConfiguration.updateResults(.empty)
                return
            }
            await newQuery.getData(defaults: NrqlConnection(accountIds: request.config.accountIdList))
            guard !Task.isCancelled, query === newQuery, let results = newQuery.resultContainer else { return }
            chartConfiguration.updateResults(results)
        }
    }
}

#Preview {
    QueryBuilderView()
}
