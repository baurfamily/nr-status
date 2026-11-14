//
//  PreferencesView.swift
//  NR Status
//
//  Created by Eric Baur on 9/22/24.
//

import SwiftUI

struct PreferencesView: View {
    private struct AvailableAccount: Identifiable {
        let id: Int
        let name: String
    }

    @State private var settings = NerdgraphProfiles.Settings()
    @State private var profile = NerdgraphProfile(name: "")
    @State private var apiKey = ""
    @State private var accountIds = ""
    @State private var makeDefault = false
    @State private var accounts: [AvailableAccount] = []
    @State private var search = ""
    @State private var status = ""
    @State private var errorMessage: String?
    @State private var isTesting = false
    @State private var testTask: Task<Void, Never>?

    private var preferredIds: Set<Int> {
        Set(accountIds.split(separator: ",").compactMap { Int($0.trimmingCharacters(in: .whitespaces)) })
    }

    private var filteredAccounts: [AvailableAccount] {
        accounts.filter { search.isEmpty || $0.name.localizedCaseInsensitiveContains(search) || String($0.id).contains(search) }
    }

    var body: some View {
        HStack(alignment: .top, spacing: 20) {
            VStack(alignment: .leading) {
                List(settings.profiles) { item in
                    Button {
                        select(item)
                    } label: {
                        HStack {
                            Text(item.name)
                            if item.id == settings.defaultProfileID { Image(systemName: "star.fill") }
                            Spacer()
                        }
                        .contentShape(Rectangle())
                        .foregroundStyle(item.id == profile.id ? Color.accentColor : Color.primary)
                    }
                    .buttonStyle(.plain)
                }
                Button("Add API Key", systemImage: "plus") {
                    select(NerdgraphProfile(name: ""))
                }
            }
            .frame(width: 180)

            VStack(alignment: .leading, spacing: 12) {
                Form {
                    TextField("Key name", text: $profile.name)
                    TextField("API host", text: $profile.host)
                    SecureField("API key", text: $apiKey)
                    Toggle("Use as app default", isOn: $makeDefault)
                        .disabled(profile.id == settings.defaultProfileID)
                    TextField("Preferred accounts (CSV)", text: $accountIds)
                }
                Text("Documents reference the key name, not the secret. Preferred accounts are defaults and completion suggestions; other account IDs can still be entered in a query.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                HStack {
                    Button("Save") { save() }
                        .keyboardShortcut("s", modifiers: .command)
                    Button("Test & Load Accounts") { testRequest() }
                        .disabled(isTesting || apiKey.isEmpty)
                    if isTesting { ProgressView().controlSize(.small) }
                    Spacer()
                    if settings.profiles.contains(where: { $0.id == profile.id }) {
                        Button("Delete Key", role: .destructive) { remove() }
                    }
                }
                if let errorMessage {
                    Text(errorMessage).foregroundStyle(.red).textSelection(.enabled)
                }
                if !status.isEmpty { Text(status).font(.caption) }
                TextField("Search accounts by name or ID", text: $search)
                List(filteredAccounts) { account in
                    Toggle(isOn: Binding(
                        get: { preferredIds.contains(account.id) },
                        set: { toggleAccount(account.id, selected: $0) }
                    )) {
                        Text("\(account.name) (\(String(account.id)))")
                    }
                }
                Text("\(preferredIds.count) preferred / \(accounts.count) available")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .padding()
        .frame(minWidth: 740, minHeight: 480)
        .onAppear { load() }
        .onChange(of: apiKey) { clearDiscovery() }
        .onChange(of: profile.host) { clearDiscovery() }
        .onDisappear { testTask?.cancel() }
    }

    private func load() {
        do {
            settings = try NerdgraphProfiles.shared.load()
            if let current = settings.profiles.first(where: { $0.id == settings.defaultProfileID }) {
                select(current)
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func select(_ item: NerdgraphProfile) {
        clearDiscovery()
        profile = item
        accountIds = item.preferredAccountIds.map(String.init).joined(separator: ", ")
        makeDefault = item.id == settings.defaultProfileID || settings.profiles.isEmpty
        errorMessage = nil
        do {
            apiKey = try NerdgraphProfiles.shared.keychain(for: item).loadChecked()?.apiKey ?? ""
        } catch {
            apiKey = ""
            errorMessage = error.localizedDescription
        }
    }

    private func save() {
        do {
            profile.preferredAccountIds = try NerdgraphProfiles.parseAccountIds(accountIds)
            settings = try NerdgraphProfiles.shared.save(profile, apiKey: apiKey, makeDefault: makeDefault)
            if let saved = settings.profiles.first(where: { $0.id == profile.id }) { profile = saved }
            makeDefault = profile.id == settings.defaultProfileID
            errorMessage = nil
            status = "Saved."
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func remove() {
        do {
            settings = try NerdgraphProfiles.shared.remove(profile.id)
            select(settings.profiles.first ?? NerdgraphProfile(name: ""))
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func toggleAccount(_ id: Int, selected: Bool) {
        do {
            var ids = try NerdgraphProfiles.parseAccountIds(accountIds)
            if selected {
                if !ids.contains(id) { ids.append(id) }
            } else {
                ids.removeAll { $0 == id }
            }
            accountIds = ids.map(String.init).joined(separator: ", ")
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func clearDiscovery() {
        testTask?.cancel()
        isTesting = false
        accounts = []
        search = ""
        status = ""
    }

    private func testRequest() {
        clearDiscovery()
        errorMessage = nil
        isTesting = true
        let config = NerdgraphConfig(host: profile.host, apiKey: apiKey, accountIds: "")
        testTask = Task { @MainActor in
            do {
                let queries = Queries(config: config)
                async let user = queries.user()
                async let available = queries.accounts()
                let (identity, fetched) = try await (user, available)
                guard !Task.isCancelled else { return }
                guard let fetched else {
                    throw NerdgraphClient.ClientError.graphQL(["No account list was returned."])
                }
                var seen = Set<Int>()
                accounts = fetched.compactMap { account in
                    guard let id = account.id, seen.insert(id).inserted else { return nil }
                    return AvailableAccount(id: id, name: account.name ?? "Unnamed account")
                }.sorted { ($0.name, $0.id) < ($1.name, $1.id) }
                status = "Connected\(identity?.email.map { " as \($0)" } ?? ""). Select common accounts below, then Save."
            } catch {
                guard !Task.isCancelled else { return }
                errorMessage = error.localizedDescription
            }
            isTesting = false
        }
    }
}

struct TestPanelView: View {
    var name: String = ""
    
    @Binding var success: Bool?
    @Binding var description: String
    
    var systemName: String {
        if success == nil {
            return "questionmark"
        } else if success! {
            return "checkmark"
        } else {
            return "xmark"
        }
    }
    var color: Color {
        if success == nil {
            return .white
        } else if success! {
            return .green
        } else {
            return .red
        }
    }
    
    var body : some View {
        HStack {
            Image(systemName: systemName)
                .fontWidth(.expanded)
                .font(.system(size: 25))
                .background(in: RoundedRectangle(cornerRadius: 10))
                .shadow(radius: 5)
                .backgroundStyle(color)
                .fontWeight(.bold)
            
            
            Text(name)
            Text(description)
        }
    }
}

#Preview {
    PreferencesView()
}
