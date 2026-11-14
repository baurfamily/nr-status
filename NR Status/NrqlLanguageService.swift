//
//  NrqlLanguageService.swift
//  NR Status
//

import SwiftUI
import Combine
import LanguageSupport

/// Gives the code editor completions: NRQL for query cells (and Lua inside their `{{ }}`),
/// or Lua for script cells. One instance serves one cell.
final class NrqlLanguageService: LanguageService {
    enum Language { case nrql, lua, config, graphql, variables }

    private let metadata: NrqlMetadataProviding?
    private let language: Language
    private let lock = NSLock()
    private var openedText = ""
    private var textSource: (() -> String)?
    private var scopeSource: (() -> LuaCompletion.Scope)?
    private var connectionSource: (() -> Result<NrqlConnection, Error>)?
    private var lastChange = Date.distantPast
    private var completionAction: (() -> Void)?
    private let schemaStore = NerdgraphSchemaStore()
    private var completionErrorHandler: ((String?) -> Void)?

    func setCompletionErrorHandler(_ handler: @escaping (String?) -> Void) {
        lock.withLock { completionErrorHandler = handler }
    }

    func graphqlSchema() async throws -> NerdgraphSchema {
        let source = lock.withLock { connectionSource }
        let defaults = await MainActor.run { source?() ?? .success(NrqlConnection()) }
        let metadata = NerdgraphCellSource(editorText: currentText).metadata
        let connection = try NrqlConnection.parse(metadata).inheriting(defaults.get())
        return try await schemaStore.schema(config: connection.resolve(requiresAccounts: false))
    }

    /// The editor's own "show completions" action, used to reopen the panel after a separator.
    func setCompletionAction(_ action: (() -> Void)?) {
        lock.withLock { completionAction = action }
    }
    /// Set to false to only show completions when asked for explicitly.
    var popsUpWhileTyping = true
    private(set) var isOpen = false

    init(metadata: NrqlMetadataProviding? = nil, language: Language = .nrql) {
        self.metadata = metadata
        self.language = language
    }

    /// The editor only reports edits, so completion reads the live text from here.
    func setTextSource(_ source: @escaping () -> String) {
        lock.withLock { textSource = source }
    }

    /// What the rest of the notebook offers to Lua; read on the main actor.
    func setScopeSource(_ source: @escaping () -> LuaCompletion.Scope) {
        lock.withLock { scopeSource = source }
    }

    func setConnectionSource(_ source: @escaping () -> Result<NrqlConnection, Error>) {
        lock.withLock { connectionSource = source }
    }

    private var currentText: String {
        lock.withLock { textSource?() ?? openedText }
    }

    // MARK: Document synchronisation

    func openDocument(with text: String, locationService: LocationService) async throws {
        lock.withLock { openedText = text }
        isOpen = true
    }

    func documentDidChange(position changeLocation: Int, changeInLength delta: Int, lineChange deltaLine: Int,
                           columnChange deltaColumn: Int, newText text: String) async throws {
        lock.withLock { lastChange = Date() }

        // The editor closes its panel when a word ends. Where the next word is a name we can
        // list, such as after a comma or a dot, bring it straight back.
        guard delta == 1 else { return }
        let source = currentText
        let next = changeLocation + 1
        let retrigger: Bool
        switch language {
        case .lua:
            retrigger = text == "."
        case .variables:
            retrigger = text == "." && LuaCompletion.interpolationStart(in: source, at: next) != nil
        case .graphql:
            retrigger = [" ", "{", "(", "$", "\n"].contains(text)
        case .nrql, .config:
            retrigger = ([" ", ",", "("].contains(text) && NrqlCompletion.offersAfterSeparator(
                text: source, location: next, configuration: language == .config
            ))
                || (text == "." && LuaCompletion.interpolationStart(in: source, at: next) != nil)
        }
        guard retrigger else { return }
        try await Task.sleep(for: .milliseconds(100))
        let action = lock.withLock { completionAction }
        await MainActor.run { action?() }
    }

    func closeDocument() async throws { isOpen = false }

    // MARK: Events and diagnostics

    let events = PassthroughSubject<LanguageServiceEvent, Never>()
    let diagnostics = CurrentValueSubject<Set<TextLocated<Message>>, Never>(Set())
    let extraActions = CurrentValueSubject<[ExtraAction], Never>([])

    // MARK: Completion

    let completionTriggerCharacters = CurrentValueSubject<[Character], Never>([])

    func completions(at location: Int, reason: CompletionTriggerReason) async throws -> Completions {
        // the editor asks right after a keystroke when it wants to pop up on its own
        if !popsUpWhileTyping, case .standard = reason,
           lock.withLock({ Date().timeIntervalSince(lastChange) }) < 0.4 {
            return .none
        }
        let text = currentText
        let items: [NrqlCompletion.Item]
        let range: NSRange
        switch language {
        case .lua:
            let scope = await currentScope()
            (items, range) = LuaCompletion.items(text: text, location: location, scope: scope)
        case .variables:
            guard let start = LuaCompletion.interpolationStart(in: text, at: location) else { return .none }
            let scope = await currentScope()
            let found = LuaCompletion.items(
                text: (text as NSString).substring(from: start), location: location - start, scope: scope, isExpression: true
            )
            items = found.items
            range = NSRange(location: found.range.location + start, length: found.range.length)
        case .graphql:
            let source = lock.withLock { connectionSource }
            let defaults = await MainActor.run { source?() ?? .success(NrqlConnection()) }
            let context = NrqlCompletion.analyse(text: text, location: location, configuration: true, graphql: true).context
            switch context {
            case .formatKey, .formatValue:
                let settings = try NerdgraphProfiles.shared.load()
                let found = await NrqlCompletion.items(
                    text: text, location: location, metadata: NrqlMetadata.Source(connection: defaults),
                    profiles: settings.profiles, defaultKeyName: try defaults.get().apiKeyName,
                    configuration: true, graphql: true
                )
                items = found.items
                range = found.range
            default:
                do {
                    let schema = try await graphqlSchema()
                    (items, range) = NerdgraphCompletion.items(text: text, location: location, schema: schema)
                    let handler = lock.withLock { completionErrorHandler }
                    await MainActor.run { handler?(nil) }
                } catch {
                    let handler = lock.withLock { completionErrorHandler }
                    await MainActor.run { handler?(error.localizedDescription) }
                    throw error
                }
            }
        case .nrql, .config:
            if language == .nrql, let start = LuaCompletion.interpolationStart(in: text, at: location) {
                let scope = await currentScope()
                let expression = (text as NSString).substring(from: start)
                let found = LuaCompletion.items(
                    text: expression, location: location - start, scope: scope, isExpression: true
                )
                items = found.items
                range = NSRange(location: found.range.location + start, length: found.range.length)
            } else {
                let source = lock.withLock { connectionSource }
                let defaults = await MainActor.run { source?() ?? .success(NrqlConnection()) }
                let connection = Result {
                    try NrqlConnection.parse(NrqlConnection.metadataBody(in: text)).inheriting(defaults.get())
                }
                let settings = try NerdgraphProfiles.shared.load()
                let defaultName = (try? defaults.get().apiKeyName)
                    ?? settings.profiles.first(where: { $0.id == settings.defaultProfileID })?.name
                (items, range) = await NrqlCompletion.items(
                    text: text, location: location, metadata: metadata ?? NrqlMetadata.Source(connection: connection),
                    profiles: settings.profiles, defaultKeyName: defaultName, configuration: language == .config
                )
            }
        }
        guard !items.isEmpty else { return .none }

        return Completions(
            isIncomplete: false,
            items: items.enumerated().map { index, item in
                Completions.Completion(
                    id: index,
                    rowView: { _ in
                        HStack {
                            Text(item.name)
                            Spacer()
                            Text(item.detail ?? item.kind.label).foregroundStyle(.secondary).font(.caption)
                        }
                    },
                    documentationView: Text(item.detail ?? "\(item.kind.label.capitalized): \(item.name)"),
                    selected: index == 0,
                    sortText: String(format: "%06d", index),
                    filterText: item.name,
                    insertText: item.insertText,
                    insertRange: range,
                    commitCharacters: [],
                    refine: { nil }
                )
            }
        )
    }

    // MARK: Unused features

    private func currentScope() async -> LuaCompletion.Scope {
        let source = lock.withLock { scopeSource }
        return await MainActor.run { source?() ?? .empty }
    }

    func tokens(for lineRange: Range<Int>) async throws -> [[(token: LanguageConfiguration.Token, range: NSRange)]] {
        Array(repeating: [], count: lineRange.count)
    }

    func info(at location: Int) async throws -> (view: any View, anchor: NSRange?)? { nil }

    func capabilities() async throws -> (any View)? { nil }
}
