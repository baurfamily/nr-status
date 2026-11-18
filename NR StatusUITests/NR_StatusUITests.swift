//
//  NR_StatusUITests.swift
//  NR StatusUITests
//
//  Created by Eric Baur on 9/21/24.
//

import XCTest

final class NR_StatusUITests: XCTestCase {
    private func openInApp(_ url: URL) throws {
        var runner = Bundle(for: Self.self).bundleURL
        while runner.pathExtension != "app" && runner.path != "/" {
            runner.deleteLastPathComponent()
        }
        let application = runner.deletingLastPathComponent().appendingPathComponent("NR Status.app")
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        process.arguments = ["-a", application.path, url.absoluteString]
        try process.run()
        process.waitUntilExit()
        XCTAssertEqual(process.terminationStatus, 0)
    }

    @MainActor
    func testWidgetLinkReopensSourceAndRecoversMissingWorkbook() throws {
        let id = UUID()
        let link = try XCTUnwrap(URL(string: "nrstatus://widget/\(id.uuidString)"))
        let file = FileManager.default.temporaryDirectory.appendingPathComponent("widget-source-\(id).nrmd")
        let recovered = file.deletingLastPathComponent().appendingPathComponent("recovered-\(id).nrmd")
        try """
            ```cell_config
            widget-id: \(id)
            title: Widget navigation target
            query: hide
            ```
            ```lua
            return { rows = { { count = 42 } } }
            ```
            """.write(to: file, atomically: true, encoding: .utf8)
        defer {
            try? FileManager.default.removeItem(at: file)
            try? FileManager.default.removeItem(at: recovered)
        }

        let app = XCUIApplication()
        app.launchArguments = ["-ApplePersistenceIgnoreState", "YES"]
        app.launch()
        try openInApp(file)
        let window = app.windows[file.lastPathComponent]
        XCTAssertTrue(window.waitForExistence(timeout: 5))
        XCTAssertTrue(window.buttons["Show query"].firstMatch.exists)
        window.menuButtons["Cell Actions"].firstMatch.click()
        app.menuItems["Publish as Widget..."].click()
        let publish = app.buttons["Publish"].firstMatch
        XCTAssertTrue(publish.waitForExistence(timeout: 5))
        publish.click()
        XCTAssertTrue(window.staticTexts["Published"].firstMatch.waitForExistence(timeout: 5))
        app.typeKey("s", modifierFlags: .command)
        app.terminate()
        try openInApp(link)
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 10))
        XCTAssertTrue(window.waitForExistence(timeout: 5))
        XCTAssertTrue(window.buttons["Hide query"].firstMatch.waitForExistence(timeout: 5))
        window.buttons["Hide query"].firstMatch.click()
        try openInApp(link)
        XCTAssertTrue(window.buttons["Hide query"].firstMatch.waitForExistence(timeout: 5))

        app.typeKey("w", modifierFlags: .command)
        try FileManager.default.removeItem(at: file)
        try openInApp(link)
        let missing = app.dialogs.firstMatch
        XCTAssertTrue(missing.staticTexts["Widget chart source file not found"].waitForExistence(timeout: 5))
        XCTAssertTrue(missing.staticTexts.containing(NSPredicate(format: "value CONTAINS %@", "workbook dependencies")).firstMatch.exists)
        missing.buttons["Recover Workbook..."].click()
        let save = app.dialogs.buttons["Save"].firstMatch
        XCTAssertTrue(save.waitForExistence(timeout: 5))
        app.typeKey("g", modifierFlags: [.command, .shift])
        app.typeText(recovered.path)
        app.typeKey(.return, modifierFlags: [])
        save.click()
        let recoveredWindow = app.windows[recovered.lastPathComponent]
        XCTAssertTrue(recoveredWindow.waitForExistence(timeout: 5))
        XCTAssertTrue(recoveredWindow.staticTexts["Widget navigation target"].firstMatch.exists)
        XCTAssertTrue(try String(contentsOf: recovered, encoding: .utf8).contains("count = 42"))

        recoveredWindow.menuButtons["Cell Actions"].firstMatch.click()
        app.menuItems["Unpublish Widget"].click()
        try openInApp(link)
        let removed = app.dialogs.firstMatch
        XCTAssertTrue(removed.staticTexts["Widget chart source file not found"].waitForExistence(timeout: 5))
        XCTAssertFalse(removed.buttons["Recover Workbook..."].exists)
        removed.buttons["OK"].click()
    }

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.

        // In UI tests it is usually best to stop immediately when a failure occurs.
        continueAfterFailure = false

        // In UI tests it’s important to set the initial state - such as interface orientation - required for your tests before they run. The setUp method is a good place to do this.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    @MainActor
    func testExample() throws {
        // UI tests must launch the application that they test.
        let app = XCUIApplication()
        app.launch()

        // Use XCTAssert and related functions to verify your tests produce the correct results.
    }

    @MainActor
    func testCellConfigurationFormAndTextStaySynchronizedBeforeRunning() throws {
        let app = XCUIApplication()
        app.launch()
        app.typeKey("n", modifierFlags: .command)
        let configure = app.buttons["Configure Cell"].firstMatch
        XCTAssertTrue(configure.waitForExistence(timeout: 5))
        configure.click()
        let title = app.textFields["cell-configuration-title"]
        XCTAssertTrue(title.waitForExistence(timeout: 5))
        title.click()
        title.typeKey("a", modifierFlags: .command)
        title.typeText("ConfiguredTitle")
        for label in ["Title", "Variable binding", "Account IDs"] {
            XCTAssertTrue(app.staticTexts[label].exists)
        }
        XCTAssertFalse(app.staticTexts["API Key name"].exists)
        XCTAssertFalse(app.textFields["API Key name"].exists)
        XCTAssertTrue(app.buttons["Remove Cell Configuration"].exists)
        XCTAssertFalse(app.staticTexts["Remove Cell Configuration"].exists)
        app.radioButtons["Text"].firstMatch.click()
        let text = app.textViews["cell-configuration-text"]
        XCTAssertTrue(text.waitForExistence(timeout: 5))
        XCTAssertTrue((text.value as? String)?.contains("title: ConfiguredTitle") == true)
        text.click()
        text.typeKey("a", modifierFlags: .command)
        text.typeText("title: From text\napi-key: Staging\nchart: billboard\nattributes: gauge, max(250)")
        app.radioButtons["Settings"].firstMatch.click()
        XCTAssertEqual(title.value as? String, "From text")
        XCTAssertFalse(app.textFields["API Key name"].exists)
        let maximum = app.textFields["Maximum value"]
        XCTAssertTrue(maximum.waitForExistence(timeout: 5))
        XCTAssertEqual(maximum.value as? String, "250")
        XCTAssertTrue(app.staticTexts["Maximum value"].exists)
        maximum.click()
        maximum.typeKey("a", modifierFlags: .command)
        maximum.typeText("500")
        app.radioButtons["Text"].firstMatch.click()
        XCTAssertTrue((text.value as? String)?.contains("max(500)") == true)
        XCTAssertTrue((text.value as? String)?.contains("api-key: Staging") == true)

        app.buttons["Close"].firstMatch.click()
        app.buttons["Document Config"].firstMatch.click()
        app.radioButtons["Settings"].firstMatch.click()
        let documentKey = app.textFields["API Key name"]
        XCTAssertTrue(documentKey.waitForExistence(timeout: 5))
        documentKey.click()
        documentKey.typeText("Production")
        app.radioButtons["Text"].firstMatch.click()
        XCTAssertTrue((text.value as? String)?.contains("api-key: Production") == true)
    }

    @MainActor
    func testFrontmatterSummaryCanBeExpandedEditedAndCollapsed() throws {
        let file = FileManager.default.temporaryDirectory.appendingPathComponent("config-summary-\(UUID().uuidString).nrmd")
        try """
            ---
            author: Example team
            description: "Example: summary"
            ---

            # Workbook notes
            """.write(to: file, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: file) }
        let app = XCUIApplication()
        app.launchArguments = ["-ApplePersistenceIgnoreState", "YES"]
        app.launch()
        app.typeKey("o", modifierFlags: .command)
        app.typeKey("g", modifierFlags: [.command, .shift])
        app.typeText(file.path)
        app.typeKey(.return, modifierFlags: [])
        app.typeKey(.return, modifierFlags: [])
        let window = app.windows[file.lastPathComponent]
        XCTAssertTrue(window.waitForExistence(timeout: 5), app.debugDescription)
        let summary = window.descendants(matching: .any)["document-configuration-summary"].firstMatch
        XCTAssertFalse(summary.exists)
        window.buttons["Show config"].firstMatch.click()
        XCTAssertTrue(summary.waitForExistence(timeout: 5))
        XCTAssertTrue(window.staticTexts["Example team"].exists)
        XCTAssertTrue(window.staticTexts["Example: summary"].exists)

        window.buttons["Configure Cell"].firstMatch.click()
        window.radioButtons["Text"].firstMatch.click()
        let text = window.textViews["cell-configuration-text"]
        XCTAssertTrue(text.waitForExistence(timeout: 5))
        text.click()
        text.typeKey("a", modifierFlags: .command)
        text.typeText("author: Updated team\ndescription: A new summary")
        window.buttons["Close"].firstMatch.click()
        XCTAssertTrue(window.staticTexts["Updated team"].waitForExistence(timeout: 5))
        window.buttons["Hide config"].firstMatch.click()
        XCTAssertFalse(summary.exists)
        app.typeKey("s", modifierFlags: .command)
        let saved = NSPredicate { _, _ in
            guard let source = try? String(contentsOf: file, encoding: .utf8) else { return false }
            return source.hasPrefix("---\n") && source.contains("Updated team") && source.contains("# Workbook notes")
        }
        expectation(for: saved, evaluatedWith: nil)
        waitForExpectations(timeout: 5)
    }

    @MainActor
    func testGraphQLWholeResponseAndExtractionEditorsStaySeparate() throws {
        let file = FileManager.default.temporaryDirectory.appendingPathComponent("binding-split-\(UUID().uuidString).nrmd")
        try """
            ```cell_config
            var: response
            bindings:
              - name: account
                expression: data.actor.account
            ```
            ```graphql
            { actor { user { name } } }
            ```
            """.write(to: file, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: file) }
        let app = XCUIApplication()
        app.launchArguments = ["-ApplePersistenceIgnoreState", "YES"]
        app.launch()
        app.typeKey("o", modifierFlags: .command)
        app.typeKey("g", modifierFlags: [.command, .shift])
        app.typeText(file.path)
        app.typeKey(.return, modifierFlags: [])
        app.typeKey(.return, modifierFlags: [])
        let window = app.windows[file.lastPathComponent]
        XCTAssertTrue(window.waitForExistence(timeout: 5))
        window.buttons["Configure Cell"].firstMatch.click()
        let whole = window.textFields["cell-result-variable"]
        XCTAssertTrue(whole.waitForExistence(timeout: 5))
        XCTAssertEqual(whole.value as? String, "response")
        let name = window.textFields["binding-name-0"]
        XCTAssertEqual(name.value as? String, "account")
        name.click()
        name.typeKey("a", modifierFlags: .command)
        name.typeText("accountName")
        let expression = window.textViews["binding-expression-0"]
        expression.click()
        expression.typeKey("a", modifierFlags: .command)
        expression.typeText("data.actor.account.name")
        window.radioButtons["Text"].firstMatch.click()
        let text = window.textViews["cell-configuration-text"]
        XCTAssertTrue(text.waitForExistence(timeout: 5))
        XCTAssertTrue((text.value as? String)?.contains("var: response") == true)
        XCTAssertTrue((text.value as? String)?.contains("name: accountName") == true)
        XCTAssertTrue((text.value as? String)?.contains("expression: data.actor.account.name") == true)
        text.click()
        text.typeKey("a", modifierFlags: .command)
        text.typeText("var: fullResponse\nbindings:\n  - name: actor\n    expression: data.actor")
        window.radioButtons["Settings"].firstMatch.click()
        XCTAssertEqual(whole.value as? String, "fullResponse")
        XCTAssertEqual(name.value as? String, "actor")
        XCTAssertEqual(expression.value as? String, "data.actor")
        window.buttons["remove-binding-0"].click()
        XCTAssertFalse(name.exists)
        XCTAssertEqual(whole.value as? String, "fullResponse")
        window.buttons["add-result-binding"].click()
        XCTAssertTrue(name.waitForExistence(timeout: 5))
        name.click()
        name.typeText("currentUser")
        expression.click()
        expression.typeText("data.actor.user")
        window.radioButtons["Text"].firstMatch.click()
        XCTAssertTrue((text.value as? String)?.contains("var: fullResponse") == true)
        XCTAssertTrue((text.value as? String)?.contains("name: currentUser") == true)
        XCTAssertTrue((text.value as? String)?.contains("expression: data.actor.user") == true)
    }

    @MainActor
    func testDocumentBindingsUseStructuredSettingsAndRoundTripThroughText() throws {
        let file = FileManager.default.temporaryDirectory.appendingPathComponent("document-bindings-\(UUID().uuidString).nrmd")
        try """
            ---
            author: Binding example
            bindings:
              - name: service
                expression: '"Checkout"'
            ---

            # Notes
            """.write(to: file, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: file) }
        let app = XCUIApplication()
        app.launchArguments = ["-ApplePersistenceIgnoreState", "YES"]
        app.launch()
        app.typeKey("o", modifierFlags: .command)
        app.typeKey("g", modifierFlags: [.command, .shift])
        app.typeText(file.path)
        app.typeKey(.return, modifierFlags: [])
        app.typeKey(.return, modifierFlags: [])
        let window = app.windows[file.lastPathComponent]
        XCTAssertTrue(window.waitForExistence(timeout: 5))
        window.buttons["Configure Cell"].firstMatch.click()
        let name = window.textFields["binding-name-0"]
        XCTAssertTrue(name.waitForExistence(timeout: 5))
        XCTAssertEqual(name.value as? String, "service")
        XCTAssertFalse(window.textFields["cell-result-variable"].exists)
        let expression = window.textViews["binding-expression-0"]
        XCTAssertEqual(expression.value as? String, "\"Checkout\"")
        name.click()
        name.typeKey("a", modifierFlags: .command)
        name.typeText("serviceName")
        expression.click()
        expression.typeKey("a", modifierFlags: .command)
        expression.typeText("\"Payments\"")
        window.radioButtons["Text"].firstMatch.click()
        let text = window.textViews["cell-configuration-text"]
        XCTAssertTrue(text.waitForExistence(timeout: 5))
        XCTAssertTrue((text.value as? String)?.contains("bindings:") == true)
        XCTAssertTrue((text.value as? String)?.contains("name: serviceName") == true)
        XCTAssertTrue((text.value as? String)?.contains("Payments") == true)
        XCTAssertFalse((text.value as? String)?.contains("var:") == true)
        text.click()
        text.typeKey("a", modifierFlags: .command)
        text.typeText("author: Binding example\nbindings:\n  - name: appName\n    expression: '\"Inventory\"'")
        window.radioButtons["Settings"].firstMatch.click()
        XCTAssertEqual(name.value as? String, "appName")
        XCTAssertEqual(expression.value as? String, "\"Inventory\"")
        window.buttons["remove-binding-0"].click()
        XCTAssertFalse(name.exists)
        window.buttons["add-result-binding"].click()
        XCTAssertTrue(name.waitForExistence(timeout: 5))
        name.click()
        name.typeText("threshold")
        expression.click()
        expression.typeText("12")
        window.buttons["Close"].firstMatch.click()
        app.typeKey("s", modifierFlags: .command)
        let saved = NSPredicate { _, _ in
            guard let source = try? String(contentsOf: file, encoding: .utf8) else { return false }
            return source.hasPrefix("---\n") && source.contains("name: threshold")
                && source.contains("author: Binding example") && source.contains("# Notes")
                && !source.contains("var:")
        }
        expectation(for: saved, evaluatedWith: nil)
        waitForExpectations(timeout: 5)
    }

    @MainActor
    func testLuaConsoleDisplaysPrintOutputAndCanBeSelectedInSettings() throws {
        let file = FileManager.default.temporaryDirectory.appendingPathComponent("lua-console-\(UUID().uuidString).nrmd")
        try """
            ```cell_config
            title: Console report
            chart: console
            ```
            ```lua
            print("Service", "Checkout")
            print("Count: 42")
            ```
            """.write(to: file, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: file) }
        let app = XCUIApplication()
        app.launchArguments = ["-ApplePersistenceIgnoreState", "YES"]
        app.launch()
        app.typeKey("o", modifierFlags: .command)
        app.typeKey("g", modifierFlags: [.command, .shift])
        app.typeText(file.path)
        app.typeKey(.return, modifierFlags: [])
        app.typeKey(.return, modifierFlags: [])
        let window = app.windows[file.lastPathComponent]
        XCTAssertTrue(window.waitForExistence(timeout: 5))
        window.buttons["Run"].firstMatch.click()
        let console = window.descendants(matching: .any)["lua-console-output"].firstMatch
        XCTAssertTrue(console.waitForExistence(timeout: 5))
        XCTAssertEqual(console.value as? String, "Service\tCheckout\nCount: 42", console.debugDescription)
        window.buttons["Configure Cell"].firstMatch.click()
        XCTAssertFalse(window.textFields["cell-chart-height"].exists)
        let display = window.descendants(matching: .any)["cell-display-selector"].firstMatch
        display.click()
        app.menuItems["JSON"].click()
        XCTAssertFalse(console.exists)
        display.click()
        app.menuItems["Console"].click()
        XCTAssertTrue(console.waitForExistence(timeout: 5))
        XCTAssertEqual(console.value as? String, "Service\tCheckout\nCount: 42", console.debugDescription)
        window.buttons["Close"].firstMatch.click()
        window.buttons["Clear Results"].click()
        XCTAssertFalse(console.exists)
        window.buttons["Run"].firstMatch.click()
        XCTAssertTrue(console.waitForExistence(timeout: 5))
        XCTAssertEqual(console.value as? String, "Service\tCheckout\nCount: 42", console.debugDescription)
    }

    @MainActor
    func testQueryBuilderOffersAnAccountPicker() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-ApplePersistenceIgnoreState", "YES"]
        app.launch()
        app.menuBars.menuBarItems["Features"].click()
        app.menuItems["Query Builder"].click()
        let picker = app.popUpButtons["query-builder-account-picker"]
        XCTAssertTrue(picker.waitForExistence(timeout: 5))
        picker.click()
        XCTAssertTrue(app.menuItems["Default (all preferred accounts)"].waitForExistence(timeout: 5))
        app.typeKey(.escape, modifierFlags: [])
    }

    @MainActor
    func testChartHeightCanBeDraggedAndReset() throws {
        let file = FileManager.default.temporaryDirectory.appendingPathComponent("chart-resize-\(UUID().uuidString).nrmd")
        try """
            ```cell_config
            title: Resize chart
            height: 20
            ```
            ```lua
            return { rows = { { count = 50 } } }
            ```
            """.write(to: file, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: file) }

        let app = XCUIApplication()
        app.launchArguments = ["-ApplePersistenceIgnoreState", "YES"]
        app.launch()
        app.typeKey("o", modifierFlags: .command)
        app.typeKey("g", modifierFlags: [.command, .shift])
        app.typeText(file.path)
        app.typeKey(.return, modifierFlags: [])
        app.typeKey(.return, modifierFlags: [])
        let window = app.windows[file.lastPathComponent]
        XCTAssertTrue(window.waitForExistence(timeout: 5))
        let run = window.buttons["Run"].firstMatch
        XCTAssertTrue(run.waitForExistence(timeout: 5))
        run.click()
        let handle = window.descendants(matching: .any)["chart-height-resize-handle"].firstMatch
        XCTAssertTrue(handle.waitForExistence(timeout: 10))
        window.buttons["Configure Cell"].firstMatch.click()
        let height = window.textFields["cell-chart-height"]
        XCTAssertTrue(height.waitForExistence(timeout: 5))
        XCTAssertEqual(height.value as? String, "20")
        XCTAssertEqual(handle.frame.height, 12, accuracy: 1)
        let start = handle.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        start.click(forDuration: 0.1, thenDragTo: start.withOffset(CGVector(dx: 0, dy: 75)))
        XCTAssertEqual(height.value as? String, "25")

        XCTAssertEqual(height.value as? String, "25")
        window.radioButtons["Text"].firstMatch.click()
        let text = window.textViews["cell-configuration-text"]
        XCTAssertTrue((text.value as? String)?.contains("height: 25") == true)
        handle.doubleClick()
        let automatic = NSPredicate(format: "NOT (value CONTAINS %@)", "height:")
        expectation(for: automatic, evaluatedWith: text)
        waitForExpectations(timeout: 5)
        XCTAssertTrue(handle.exists)
    }

    @MainActor
    func testLaunchPerformance() throws {
        if #available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 7.0, *) {
            // This measures how long it takes to launch your application.
            measure(metrics: [XCTApplicationLaunchMetric()]) {
                XCUIApplication().launch()
            }
        }
    }
}
