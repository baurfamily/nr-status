//
//  NRQL_EditorApp.swift
//  NRQL Editor
//
//  Created by Eric Baur on 10/14/24.
//

import SwiftUI

struct DocumentFocusedValueKey: FocusedValueKey {
  typealias Value = Binding<NRQL_EditorDocument>
}

struct QueryFocusedValueKey: FocusedValueKey {
    typealias Value = Binding<NrqlQuery>
}

extension FocusedValues {
    var document: DocumentFocusedValueKey.Value? {
        get { self[DocumentFocusedValueKey.self] }
        set { self[DocumentFocusedValueKey.self] = newValue }
    }

    var query: QueryFocusedValueKey.Value? {
        get { self[QueryFocusedValueKey.self] }
        set { self[QueryFocusedValueKey.self] = newValue }
    }
}

/// Opens a blank document at launch instead of the file picker, unless windows were restored.
/// If the user then opens a file, the untouched blank document is closed.
final class AppDelegate: NSObject, NSApplicationDelegate {
    private weak var launchDocument: NSDocument?
    private var observer: Any?

    func applicationDidFinishLaunching(_ notification: Notification) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [self] in
            let hasWindow = NSApp.windows.contains { $0.isVisible && !($0 is NSPanel) }
            guard !hasWindow else { return }
            NSApp.windows.compactMap { $0 as? NSOpenPanel }.forEach { $0.cancel(nil) }
            NSDocumentController.shared.newDocument(nil)
            launchDocument = NSDocumentController.shared.documents.first
            observer = NotificationCenter.default.addObserver(
                forName: NSWindow.didBecomeMainNotification, object: nil, queue: .main
            ) { [weak self] _ in
                MainActor.assumeIsolated { self?.closeLaunchDocumentIfReplaced() }
            }
        }
    }

    private func closeLaunchDocumentIfReplaced() {
        guard let blank = launchDocument else { return stopWatching() }
        if blank.isDocumentEdited || blank.fileURL != nil { return stopWatching() }
        let opened = NSDocumentController.shared.documents.contains { $0 !== blank && $0.fileURL != nil }
        guard opened else { return }
        blank.close()
        stopWatching()
    }

    private func stopWatching() {
        if let observer { NotificationCenter.default.removeObserver(observer) }
        observer = nil
        launchDocument = nil
    }
}

@main
struct NRQL_EditorApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @Environment(\.openWindow) var openWindow

    var body: some Scene {
        // first, so File > New (Cmd-N) creates a saveable document
        DocumentGroup(newDocument: NRQL_EditorDocument()) { file in
            DocumentView(document: file.$document)
                .focusedSceneValue(\.document, file.$document)
        }

        WindowGroup(id: "nrql-editor") { NrqlEditorWindow() }
        WindowGroup(id: "query-builder") { QueryBuilderView() }
        .commands {
            CommandMenu("Features") {
                Button(action: {
                    openWindow(id: "nrql-editor")
                }, label: {
                    Text("NRQL Editor")
                }).keyboardShortcut("n", modifiers: [ .command, .shift ])
                Button(action: {
                    openWindow(id: "query-builder")
                }, label: {
                    Text("Query Builder")
                }).keyboardShortcut("e", modifiers: [ .command, .shift ])
            }
            CommandMenu("Editor") { EditorMenuView() }
            CommandGroup(after: .importExport) { ExportMenuView() }
        }
            
        Settings {
            PreferencesView()
        }
    }
}
