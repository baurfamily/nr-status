//
//  NR_StatusTests.swift
//  NR StatusTests
//
//  Created by Eric Baur on 9/21/24.
//

import Testing
import Foundation
import AppKit
import SwiftUI
@testable import NR_Status

@MainActor
struct BindingResultsLayoutTests {
    private func scrollViewCount(in view: NSView) -> Int {
        (view is NSScrollView ? 1 : 0) + view.subviews.reduce(0) { $0 + scrollViewCount(in: $1) }
    }

    @Test(arguments: [280.0, 440.0])
    func bindingRowsFitTheirContentWithoutNestedScrolling(_ width: Double) {
        let bindings = (0..<12).map { index in
            BindingResult(
                name: "binding_\(index)", expression: "data.actor.entitySearch.results.entities[1].tags[1].key",
                value: .string("A bound value that wraps when the available width is narrow")
            )
        }
        func height(for bindings: [BindingResult]) -> CGFloat {
            let host = NSHostingView(rootView: BindingResultsView(bindings: bindings)
                .frame(width: width).fixedSize(horizontal: false, vertical: true))
            host.frame = NSRect(x: 0, y: 0, width: width, height: 1)
            host.layoutSubtreeIfNeeded()
            #expect(scrollViewCount(in: host) == 0)
            #expect(host.fittingSize.width <= width)
            return host.fittingSize.height
        }
        let singleRowHeight = height(for: [bindings[0]])
        #expect(singleRowHeight > 0)
        #expect(height(for: bindings) > singleRowHeight)
    }

    @Test func workbookInspectorHasNoPerSectionScrollViews() {
        let document = NRQL_EditorDocument(text: """
            ```config
            var service = "Checkout"
            ```

            ```cell_config
            var: traffic
            ```
            ```nrql
            SELECT count(*) FROM Transaction
            ```
            """)
        let host = NSHostingView(rootView: WorkbookBindingsView(document: document, profiles: .init()))
        host.frame = NSRect(x: 0, y: 0, width: 320, height: 500)
        host.layoutSubtreeIfNeeded()
        #expect(scrollViewCount(in: host) <= 1)
    }
}

@MainActor
struct InspectorWindowExpansionTests {
    @Test(arguments: [1200.0, 1700.0, 2000.0])
    func growsOnlyIntoAvailableSpaceOnTheRight(_ screenWidth: Double) {
        let original = NSRect(x: 100, y: 120, width: 900, height: 700)
        let screen = NSRect(x: 0, y: 0, width: screenWidth, height: 1000)
        let expanded = InspectorWindowExpansion.expandedFrame(
            from: original, inspectorWidth: 440, visibleFrame: screen, maxWidth: 1800
        )
        let expectedWidth = original.width + min(CGFloat(440), screen.width - original.maxX)
        #expect(expanded.origin == original.origin)
        #expect(expanded.height == original.height)
        #expect(abs(expanded.width - expectedWidth) < 0.5)
        #expect(expanded.maxX <= screen.maxX)
    }

    @Test func respectsWindowLimitsAndDoesNotShrinkWhenThereIsNoSpace() {
        let original = NSRect(x: 100, y: 120, width: 900, height: 700)
        let screen = NSRect(x: 0, y: 0, width: 2000, height: 1000)
        #expect(InspectorWindowExpansion.expandedFrame(
            from: original, inspectorWidth: 440, visibleFrame: screen, maxWidth: 1000
        ).width == 1000)
        #expect(InspectorWindowExpansion.expandedFrame(
            from: original, inspectorWidth: 440,
            visibleFrame: NSRect(x: 0, y: 0, width: 1000, height: 1000), maxWidth: 1800
        ) == original)
    }

    @Test func closingRestoresAutomaticGrowthButPreservesAManualResize() throws {
        let screen = try #require(NSScreen.main)
        let rect = NSRect(
            x: screen.visibleFrame.minX + 20, y: screen.visibleFrame.minY + 40,
            width: min(500, screen.visibleFrame.width - 200), height: 300
        )
        let window = NSWindow(contentRect: rect, styleMask: [.titled, .resizable], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        defer { window.close() }
        let anchor = InspectorWindowExpansion.AnchorView()
        window.contentView = anchor
        let original = window.frame
        anchor.update(isPresented: true, inspectorWidth: 120)
        #expect(window.frame.width > original.width && window.frame.minX == original.minX)
        anchor.update(isPresented: false, inspectorWidth: 120)
        #expect(window.frame == original)
        anchor.update(isPresented: true, inspectorWidth: 120)
        var manual = window.frame
        manual.size.width -= 30
        window.setFrame(manual, display: false)
        anchor.update(isPresented: false, inspectorWidth: 120)
        #expect(window.frame == manual)
    }
}

struct ConfigurationTextEditorTests {
    @MainActor @Test func nativeCompletionReplacesOnlyTheBindingExpressionPrefix() throws {
        let text = "var: user = data.act"
        let host = NSHostingView(rootView: ConfigurationTextEditor(
            text: .constant(text), identifier: "completion-test",
            completionScope: {
                LuaCompletion.Scope(response: .object(["data": .object(["actor": .object([:])])]))
            }
        ))
        host.frame = NSRect(x: 0, y: 0, width: 320, height: 180)
        host.layoutSubtreeIfNeeded()
        func findTextView(in view: NSView) -> NSTextView? {
            if let textView = view as? NSTextView { return textView }
            return view.subviews.lazy.compactMap { findTextView(in: $0) }.first
        }
        let textView = try #require(findTextView(in: host))
        textView.setSelectedRange(NSRange(location: text.utf16.count, length: 0))
        let range = textView.rangeForUserCompletion
        #expect(range.location != NSNotFound)
        let completions = try #require(textView.delegate?.textView?(
            textView, completions: [], forPartialWordRange: range, indexOfSelectedItem: nil
        ))
        let completion = try #require(completions.first)
        #expect((text as NSString).replacingCharacters(in: range, with: completion) == "var: user = data.actor")
    }

    @MainActor @Test func preservesLiteralConfigurationInput() throws {
        var text = ""
        let host = NSHostingView(rootView: ConfigurationTextEditor(
            text: Binding(get: { text }, set: { text = $0 }),
            identifier: "test-configuration"
        ))
        host.frame = NSRect(x: 0, y: 0, width: 320, height: 180)
        host.layoutSubtreeIfNeeded()

        func findTextView(in view: NSView) -> NSTextView? {
            if let textView = view as? NSTextView { return textView }
            return view.subviews.lazy.compactMap { findTextView(in: $0) }.first
        }

        let textView = try #require(findTextView(in: host))
        #expect(!textView.isAutomaticQuoteSubstitutionEnabled)
        #expect(!textView.isAutomaticDashSubstitutionEnabled)
        #expect(!textView.isAutomaticTextReplacementEnabled)
        #expect(!textView.isAutomaticSpellingCorrectionEnabled)
        #expect(!textView.isRichText)
        let configuration = "var: appName = \"checkout--service\"\nvar: owner = 'team'"
        textView.insertText(configuration, replacementRange: NSRange(location: 0, length: 0))
        #expect(text == configuration)
        #expect(textView.string == configuration)
        let connection = try NrqlConnection.parseDocumentConfig(text)
        #expect(try LuaRuntime.run("return config.appName .. ':' .. config.owner", config: connection)
            .value.stringValue == "checkout--service:team")
    }
}

// Serves canned responses so the client can be exercised without a network.
final class StubURLProtocol: URLProtocol {
    nonisolated(unsafe) static var handler: ((URLRequest) throws -> (Int, Data))?

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        do {
            let (status, data) = try Self.handler?(request) ?? (500, Data())
            let response = HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: nil)!
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}

@Suite(.serialized)
struct NerdgraphClientTests {
    @MainActor @Test(arguments: ["", "timeout: 10", "timeout: 120", "timeout: invalid"])
    func nrqlCellAppliesTimeout(configuration: String) async throws {
        let suite = "NR Status timeout test \(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        let profiles = NerdgraphProfiles(
            defaults: defaults, legacyStore: KeychainStore(label: suite + " legacy", accessGroup: nil),
            labelPrefix: suite, accessGroup: nil
        )
        let profile = NerdgraphProfile(name: "Timeout", preferredAccountIds: [12])
        try profiles.save(profile, apiKey: "test-key", makeDefault: true)
        defer {
            profiles.keychain(for: profile).remove()
            defaults.removePersistentDomain(forName: suite)
        }
        nonisolated(unsafe) var captured: URLRequest?
        StubURLProtocol.handler = { request in
            captured = request
            return (200, Data(#"{"data":{"actor":{"nrql":null}},"errors":[{"message":"Query timed out"}]}"#.utf8))
        }
        let sessionConfig = URLSessionConfiguration.ephemeral
        sessionConfig.protocolClasses = [StubURLProtocol.self]
        let session = URLSession(configuration: sessionConfig)
        defer { session.invalidateAndCancel() }
        let query = NrqlQuery(from: "```cell_config\n\(configuration)\n```\n```nrql\nSELECT 1\n```")
        await query.getData(profiles: profiles, session: session)
        if configuration == "timeout: invalid" {
            #expect(captured == nil)
            #expect(query.errorMessage?.contains("timeout must be a positive whole number") == true)
        } else {
            #expect(captured?.timeoutInterval == (configuration == "timeout: 120" ? 150 : 90))
            #expect(query.executedNrql == "SELECT 1")
            let seconds = configuration.isEmpty ? 30 : configuration == "timeout: 10" ? 10 : 120
            #expect(query.errorMessage?.contains("timed out after \(seconds) seconds") == true)
            #expect(query.errorMessage?.contains("timeout: 120") == true)
            #expect(!query.hasResult)
        }
    }

    @MainActor @Test func multipleResultBindingsExportValuesAndReportMissingPaths() async throws {
        let suite = "NR Status extracted bindings test \(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        let profiles = NerdgraphProfiles(
            defaults: defaults, legacyStore: KeychainStore(label: suite + " legacy", accessGroup: nil),
            labelPrefix: suite, accessGroup: nil
        )
        let profile = NerdgraphProfile(name: "GraphQL")
        try profiles.save(profile, apiKey: "test-key", makeDefault: true)
        defer {
            profiles.keychain(for: profile).remove()
            defaults.removePersistentDomain(forName: suite)
        }
        let response = #"{"data":{"actor":{"entitySearch":{"results":{"entities":[{"name":"Foo","tags":[{"key":"a"},{"key":"b"}]}]}}}}}"#
        StubURLProtocol.handler = { _ in (200, Data(response.utf8)) }
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StubURLProtocol.self]
        let session = URLSession(configuration: configuration)
        defer { session.invalidateAndCancel() }
        let document = NRQL_EditorDocument(text: """
            ```cell_config
            var: response
            var: entity = data.actor.entitySearch.results.entities[1]
            var: tagCount = #data.actor.entitySearch.results.entities[1].tags
            ```
            ```graphql
            { actor { entitySearch(query: "name = 'Foo'") { results { entities { name tags { key } } } } } }
            ```

            ```lua
            return { rows = { { name = results.entity.name, count = results.tagCount } } }
            ```
            """)
        let query = document.cells[0].query
        await query.getData(profiles: profiles, session: session)
        #expect(query.errorMessage == nil)
        #expect(document.priorResults.map(\.name) == ["response", "entity", "tagCount"])
        #expect(query.inspectedBindings.map(\.name) == ["response", "entity", "tagCount"])
        #expect(query.inspectedBindings.last?.value == .number(2))
        #expect(try LuaRuntime.run(
            "return response == nil and entity == nil and tagCount == nil", results: document.priorResults
        ).value.boolValue == true)
        await document.cells[1].query.getData(results: document.priorResults, profiles: profiles)
        #expect(document.cells[1].query.resultContainer?.data.first?.numberFields["count"] == 2)
        #expect(document.cells[1].query.resultContainer?.data.first?.stringFields["name"] == "Foo")
        let original = query.text
        query.text = query.text.replacingOccurrences(of: "tagCount = #data.actor.entitySearch.results.entities[1].tags",
                                                     with: "tagCount = 7")
        #expect(document.staleCellIds(profiles: try profiles.load()) == Set(document.cells.map(\.id)))
        query.text = original
        query.text = query.text.replacingOccurrences(of: "tagCount =", with: "renamedCount =")
        #expect(NrqlDependencies.dependencies(of: document.cells[1], in: document.cells).map(\.id) == [document.cells[0].id])
        #expect(document.staleCellIds(profiles: try profiles.load()) == Set(document.cells.map(\.id)))
        query.text = original
        query.text = query.text.replacingOccurrences(of: "entity = data.actor.entitySearch.results.entities[1]",
                                                     with: "entity = data.actor.entitySearch.results.entities[9]")
        await query.getData(profiles: profiles, session: session)
        #expect(query.errorMessage?.contains("Nerdgraph variable 'entity'") == true)
        #expect(query.namedResults.isEmpty)
        #expect(!query.hasResult)
        #expect(query.jsonResult == (try JSONDecoder().decode(JSONValue.self, from: Data(response.utf8))))
        #expect(query.inspectedBindings[1].error?.contains("entity") == true)
        #expect(query.inspectedBindings[2].value == .number(2))
        #expect(query.inspectedBindings[0].value != nil)
        #expect(query.displayedJSON != nil)
        #expect(NrqlDependencies.plan(
            for: [document.cells[1]], in: document.cells, includeFinished: false
        ).first?.id == document.cells[0].id)
        query.text = query.text.replacingOccurrences(of: "var: response", with: "chart: none\nvar: response")
        #expect(query.showsResultPane)
        #expect(query.displayedJSON != nil)
        query.text = query.text.replacingOccurrences(of: "tagCount = #data.actor.entitySearch.results.entities[1].tags",
                                                     with: "tagCount =")
        StubURLProtocol.handler = { _ in (200, Data(#"{"data":{"marker":"new response"}}"#.utf8)) }
        await query.getData(profiles: profiles, session: session)
        #expect(query.errorMessage?.contains("tagCount") == true)
        #expect(query.jsonResult != nil)
        #expect(query.jsonResult?["data"]?["marker"] == .string("new response"))
        #expect(!query.hasResult && query.namedResults.isEmpty)
        query.text = original
        StubURLProtocol.handler = { _ in (200, Data(response.utf8)) }
        await query.getData(profiles: profiles, session: session)
        #expect(query.errorMessage == nil && query.hasResult)
        #expect(query.failedBindingResponse == nil)
        #expect(query.namedResults.map(\.name) == ["response", "entity", "tagCount"])
        query.clearResults()
        #expect(query.loadedBindings == nil)
        #expect(query.bindingResults.isEmpty && query.jsonResult == nil)
    }

    @MainActor @Test func graphqlConfigUsesDocumentAccountsRatherThanCellOverrides() async throws {
        let suite = "NR Status GraphQL config test \(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        let profiles = NerdgraphProfiles(
            defaults: defaults, legacyStore: KeychainStore(label: suite + " legacy", accessGroup: nil),
            labelPrefix: suite, accessGroup: nil
        )
        let profile = NerdgraphProfile(name: "GraphQL", preferredAccountIds: [12, 34])
        try profiles.save(profile, apiKey: "test-key", makeDefault: true)
        defer {
            profiles.keychain(for: profile).remove()
            defaults.removePersistentDomain(forName: suite)
        }
        StubURLProtocol.handler = { _ in (200, Data(#"{"data":{}}"#.utf8)) }
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StubURLProtocol.self]
        let session = URLSession(configuration: configuration)
        defer { session.invalidateAndCancel() }
        let query = NrqlQuery(from: """
            ```graphql
            # accounts: 99
            query($id: Int!) { actor { account(id: $id) { id } } }
            ```
            ```variables
            {"id": {{ config.accounts[1] }}}
            ```
            """)
        await query.getData(defaults: NrqlConnection(accountIds: [42, 17]), profiles: profiles, session: session)
        #expect(query.errorMessage == nil)
        let sent = try #require(query.executedVariables)
        #expect(try JSONDecoder().decode(JSONValue.self, from: Data(sent.utf8)) == .object(["id": .number(42)]))
        #expect(query.loadedDocumentConfig == NrqlConnection(apiKeyName: "GraphQL", accountIds: [42, 17]))
        #expect(query.loadedConnection?.accountIds.isEmpty == true)
    }

    @MainActor @Test func executesGraphqlWithNamedKeyWithoutAccountsAndPreservesPartialErrors() async throws {
        let suite = "NR Status Nerdgraph test \(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        let profiles = NerdgraphProfiles(
            defaults: defaults, legacyStore: KeychainStore(label: suite + " legacy", accessGroup: nil),
            labelPrefix: suite, accessGroup: nil
        )
        let profile = NerdgraphProfile(name: "GraphQL", host: "\(UUID().uuidString).example.com")
        try profiles.save(profile, apiKey: "test-key", makeDefault: true)
        defer {
            profiles.keychain(for: profile).remove()
            defaults.removePersistentDomain(forName: suite)
        }
        nonisolated(unsafe) var captured: URLRequest?
        let response = #"{"data":{"customField":{"id":42}},"errors":[{"message":"partial error","path":["other"]}],"extensions":{"trace":"ok"}}"#
        StubURLProtocol.handler = {
            captured = $0
            return (200, Data(response.utf8))
        }
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StubURLProtocol.self]
        let session = URLSession(configuration: configuration)
        defer { session.invalidateAndCancel() }
        let document = NRQL_EditorDocument(text: """
            ```cell_config
            api_key: GraphQL
            var: custom
            ```
            ```graphql
            query($id: Int!) { customField(id: $id, text: "{{ literal }}") { id } }
            ```
            ```variables
            {"id": {{ 6 * 7 }}}
            ```
            """)
        let query = document.cells[0].query
        await query.getData(defaults: NrqlConnection(apiKeyName: "Unavailable"), profiles: profiles, session: session)
        #expect(query.errorMessage == nil)
        #expect(query.jsonResult?["data"]?["customField"]?["id"] == .number(42))
        #expect(query.jsonResult?.graphQLErrors == ["partial error"])
        #expect(query.jsonResult?["extensions"]?["trace"] == .string("ok"))
        #expect(query.executedNrql?.contains("{{ literal }}") == true)
        #expect(query.executedNrql?.hasPrefix("query($id: Int!)") == true)
        #expect(query.loadedConnection?.accountIds.isEmpty == true)
        let request = try #require(captured)
        #expect(request.value(forHTTPHeaderField: "api-key") == "test-key")
        #expect(request.url?.host == profile.host)
        let body: Data
        if let data = request.httpBody { body = data }
        else {
            let stream = try #require(request.httpBodyStream)
            stream.open()
            defer { stream.close() }
            var data = Data()
            var buffer = [UInt8](repeating: 0, count: 1024)
            while stream.hasBytesAvailable {
                let count = stream.read(&buffer, maxLength: buffer.count)
                guard count > 0 else { break }
                data.append(contentsOf: buffer.prefix(count))
            }
            body = data
        }
        let payload = try JSONDecoder().decode(JSONValue.self, from: body)
        #expect(payload["variables"] == .object(["id": .number(42)]))
        #expect(payload["query"] == .string(try #require(query.executedNrql)))
        let sentVariables = try #require(query.executedVariables)
        #expect(try JSONDecoder().decode(JSONValue.self, from: Data(sentVariables.utf8)) == payload["variables"])
        #expect(!sentVariables.contains("{{"))
        query.text = query.text.replacingOccurrences(of: "6 * 7", with: "results.missing.id")
        #expect(query.executedVariables == sentVariables)
        let exported = NrqlExport.html(for: document)
        #expect(exported.contains("<h3>Variables:</h3>\n<pre>\(NrqlExport.escape(sentVariables))</pre>"))
        #expect(exported.contains("{{ literal }}"))
        #expect(!exported.contains("{{ 6 * 7 }}"))
        await query.getData(profiles: profiles, session: session)
        #expect(query.errorMessage != nil)
        #expect(query.executedVariables == nil)
        query.text = query.text.replacingOccurrences(of: "results.missing.id", with: "6 * 7")
        await query.getData(profiles: profiles, session: session)
        #expect(query.executedVariables == sentVariables)
        query.clearResults()
        #expect(query.executedVariables == nil)
    }

    private func makeClient() -> NerdgraphClient {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StubURLProtocol.self]
        return NerdgraphClient(host: "localhost", apiKey: "apiKey", session: URLSession(configuration: configuration))
    }

    @Test func decodesResponse() async throws {
        StubURLProtocol.handler = { _ in
            (200, Data(#"{"data":{"actor":{"user":{"email":"baur@nerdgraph.com"}}}}"#.utf8))
        }

        let root = try await makeClient().send("query { actor { user { email } } }")

        #expect(root.data?.actor?.user?.email == "baur@nerdgraph.com")
    }

    @Test func sendsApiKeyAndMethod() async throws {
        nonisolated(unsafe) var captured: URLRequest?
        StubURLProtocol.handler = { request in
            captured = request
            return (200, Data(#"{"data":{}}"#.utf8))
        }

        struct Vars: Encodable { let nrql: String }
        _ = try await makeClient().send("query", variables: Vars(nrql: "SELECT 1"))

        #expect(captured?.value(forHTTPHeaderField: "api-key") == "apiKey")
        #expect(captured?.httpMethod == "POST")
    }

    @Test(arguments: [nil, 10, 120] as [Int?])
    func sendsResolvedKeyAndMultipleAccountsAsVariables(timeout: Int?) async throws {
        nonisolated(unsafe) var captured: URLRequest?
        StubURLProtocol.handler = { request in
            captured = request
            return (200, Data(#"{"data":{}}"#.utf8))
        }
        let sessionConfig = URLSessionConfiguration.ephemeral
        sessionConfig.protocolClasses = [StubURLProtocol.self]
        let session = URLSession(configuration: sessionConfig)
        defer { session.invalidateAndCancel() }
        let config = NerdgraphConfig(host: "eu.example.com", apiKey: "selected-key", accountIds: "12,34")
        let queries = Queries(config: config, session: session)
        if let timeout {
            _ = try await queries.getNrqlData(query: "SELECT count(*) FROM Log", timeout: timeout)
        } else {
            _ = try await queries.getNrqlData(query: "SELECT count(*) FROM Log")
        }
        let expectedTimeout = timeout ?? 30

        let request = try #require(captured)
        #expect(request.url?.host == "eu.example.com")
        #expect(request.value(forHTTPHeaderField: "api-key") == "selected-key")
        #expect(request.timeoutInterval == max(90, TimeInterval(expectedTimeout) + 30))
        // URLSession may move the payload into a stream before URLProtocol sees it.
        let data: Data
        if let body = request.httpBody {
            data = body
        } else {
            let stream = try #require(request.httpBodyStream)
            stream.open()
            defer { stream.close() }
            var body = Data()
            var buffer = [UInt8](repeating: 0, count: 1024)
            while stream.hasBytesAvailable {
                let count = stream.read(&buffer, maxLength: buffer.count)
                guard count > 0 else { break }
                body.append(contentsOf: buffer.prefix(count))
            }
            data = body
        }
        let json = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        #expect((json["query"] as? String)?.contains("nrql(accounts: $accountIds, query: $nrql, timeout: \(expectedTimeout))") == true)
        let variables = try #require(json["variables"] as? [String: Any])
        #expect(variables["accountIds"] as? [Int] == [12, 34])
        #expect(variables["nrql"] as? String == "SELECT count(*) FROM Log")
    }

    @Test(arguments: [
        #"{"errors":[{"message":"Query timeout"}]}"#,
        #"{"data":{"actor":{"nrql":null}},"errors":[{"message":"Query deadline exceeded"}]}"#
    ])
    func reportsNrqlTimeoutWithoutResults(response: String) async throws {
        StubURLProtocol.handler = { _ in (200, Data(response.utf8)) }
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StubURLProtocol.self]
        let session = URLSession(configuration: configuration)
        defer { session.invalidateAndCancel() }
        let queries = Queries(config: NerdgraphConfig(host: "localhost", apiKey: "test-key", accountIds: "12"), session: session)
        await #expect(throws: Queries.NrqlError.self) {
            _ = try await queries.getNrqlData(query: "SELECT 1")
        }
    }

    @Test func preservesNrqlResultsAndUnrelatedErrors() async throws {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StubURLProtocol.self]
        let session = URLSession(configuration: configuration)
        defer { session.invalidateAndCancel() }
        let queries = Queries(config: NerdgraphConfig(host: "localhost", apiKey: "test-key", accountIds: "12"), session: session)
        StubURLProtocol.handler = { _ in
            (200, Data(#"{"data":{"actor":{"nrql":{"nrql":"SELECT 1","results":[],"metadata":{}}}},"errors":[{"message":"Other field timed out"}]}"#.utf8))
        }
        #expect(try await queries.getNrqlData(query: "SELECT 1") != nil)
        StubURLProtocol.handler = { _ in
            (200, Data(#"{"data":{"actor":{"nrql":null}},"errors":[{"message":"Invalid NRQL syntax"}]}"#.utf8))
        }
        await #expect(throws: NerdgraphClient.ClientError.self) {
            _ = try await queries.getNrqlData(query: "SELECT 1")
        }
        StubURLProtocol.handler = { _ in (200, Data(#"{"data":{}}"#.utf8)) }
        #expect(try await queries.getNrqlData(query: "SELECT 1") == nil)
        StubURLProtocol.handler = { _ in throw URLError(.timedOut) }
        await #expect(throws: Queries.NrqlError.self) {
            _ = try await queries.getNrqlData(query: "SELECT 1")
        }
        StubURLProtocol.handler = { _ in throw URLError(.notConnectedToInternet) }
        await #expect(throws: URLError.self) {
            _ = try await queries.getNrqlData(query: "SELECT 1")
        }
    }

    @Test func throwsOnHttpError() async {
        StubURLProtocol.handler = { _ in (403, Data()) }

        await #expect(throws: NerdgraphClient.ClientError.self) {
            _ = try await makeClient().send("query")
        }
    }

    @Test func completionCacheIsIsolatedByKeyHostAndAccounts() async throws {
        nonisolated(unsafe) var requestCount = 0
        StubURLProtocol.handler = { _ in
            requestCount += 1
            return (200, Data("""
                {"data":{"actor":{"nrql":{"nrql":"SHOW EVENT TYPES","metadata":{},"results":[{"eventType":"Event\(requestCount)"}]}}}}
                """.utf8))
        }
        let sessionConfig = URLSessionConfiguration.ephemeral
        sessionConfig.protocolClasses = [StubURLProtocol.self]
        let session = URLSession(configuration: sessionConfig)
        defer { session.invalidateAndCancel() }
        let metadata = NrqlMetadata(session: session)
        let original = NerdgraphConfig(host: "a.example.com", apiKey: "key-a", accountIds: "1")
        #expect(try await metadata.eventTypes(config: original) == ["Event1"])
        var changed = original
        changed.apiKey = "key-b"
        #expect(try await metadata.eventTypes(config: changed) == ["Event2"])
        changed = original
        changed.accountIds = "2"
        #expect(try await metadata.eventTypes(config: changed) == ["Event3"])
        changed = original
        changed.host = "b.example.com"
        #expect(try await metadata.eventTypes(config: changed) == ["Event4"])
        #expect(try await metadata.eventTypes(config: original) == ["Event1"])
        #expect(requestCount == 4)
    }

    @Test func schemaCacheUsesEffectiveKeyAndHostAndReportsIntrospectionErrors() async throws {
        nonisolated(unsafe) var requestCount = 0
        StubURLProtocol.handler = { _ in
            requestCount += 1
            return (200, Data(#"{"data":{"__schema":{"queryType":{"name":"Query"},"types":[]}}}"#.utf8))
        }
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StubURLProtocol.self]
        let session = URLSession(configuration: configuration)
        defer { session.invalidateAndCancel() }
        let store = NerdgraphSchemaStore(session: session)
        let config = NerdgraphConfig(host: "first.example.com", apiKey: "first-key", accountIds: "")
        #expect(try await store.schema(config: config).queryType.name == "Query")
        _ = try await store.schema(config: config)
        #expect(requestCount == 1)
        var changed = config
        changed.apiKey = "second-key"
        _ = try await store.schema(config: changed)
        changed.host = "second.example.com"
        _ = try await store.schema(config: changed)
        #expect(requestCount == 3)
        StubURLProtocol.handler = { _ in
            (200, Data(#"{"errors":[{"message":"Introspection unavailable"}]}"#.utf8))
        }
        await #expect(throws: NerdgraphClient.ClientError.self) {
            _ = try await store.schema(config: config)
        }
    }

    @Test func throwsOnGraphQLErrorWithoutData() async {
        StubURLProtocol.handler = { _ in
            (200, Data(#"{"errors":[{"message":"bad key"}]}"#.utf8))
        }

        await #expect(throws: NerdgraphClient.ClientError.self) {
            _ = try await makeClient().send("query")
        }
    }
}

struct NerdgraphConfigTests {
    @Test func parsesAccountIds() {
        let config = NerdgraphConfig(host: "h", apiKey: "k", accountIds: "123, 456,bogus,,789")
        #expect(config.accountIdList == [123, 456, 789])
    }
}
