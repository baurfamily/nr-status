//
//  NR_StatusUITests.swift
//  NR StatusUITests
//
//  Created by Eric Baur on 9/21/24.
//

import XCTest

final class NR_StatusUITests: XCTestCase {

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
        title.typeText("Configured title")
        for label in ["Title", "Variable binding", "API Key name", "Account IDs"] {
            XCTAssertTrue(app.staticTexts[label].exists)
        }
        XCTAssertTrue(app.buttons["Remove Cell Configuration"].exists)
        XCTAssertFalse(app.staticTexts["Remove Cell Configuration"].exists)
        app.radioButtons["Text"].firstMatch.click()
        let text = app.textViews["cell-configuration-text"]
        XCTAssertTrue(text.waitForExistence(timeout: 5))
        XCTAssertTrue((text.value as? String)?.contains("title: Configured title") == true)
        text.click()
        text.typeKey("a", modifierFlags: .command)
        text.typeText("title: From text\nchart: billboard\nattributes: gauge, max(250)")
        app.radioButtons["Settings"].firstMatch.click()
        XCTAssertEqual(title.value as? String, "From text")
        let maximum = app.textFields["Maximum value"]
        XCTAssertTrue(maximum.waitForExistence(timeout: 5))
        XCTAssertEqual(maximum.value as? String, "250")
        XCTAssertTrue(app.staticTexts["Maximum value"].exists)
        maximum.click()
        maximum.typeKey("a", modifierFlags: .command)
        maximum.typeText("500")
        app.radioButtons["Text"].firstMatch.click()
        XCTAssertTrue((text.value as? String)?.contains("max(500)") == true)
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
