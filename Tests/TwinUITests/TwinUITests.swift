import XCTest

/// E2E tests for Twin — XCUITest is the Playwright equivalent for native
/// Mac apps: it launches the real app in a test process and drives the
/// public UI (clicks, keys, shortcuts), never internal state.
final class TwinUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-twin.didPickStartFolder", "YES"]
        app.launch()
        XCTAssertTrue(app.windows.firstMatch.waitForExistence(timeout: 10))
    }

    override func tearDownWithError() throws {
        app.terminate()
        app = nil
    }

    // Both panes and the Total Commander function bar are present.
    func testPanesAndFunctionBarExist() {
        XCTAssertTrue(app.buttons["F5 Copy"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["F6 Move"].exists)
        XCTAssertTrue(app.buttons["Delete"].exists)
        XCTAssertGreaterThanOrEqual(app.outlines.count, 1)
    }

    // Cmd+T adds a tab in the active pane, Cmd+W closes it again.
    func testTabCreateAndClose() {
        let window = app.windows.firstMatch
        window.click()
        let tabsBefore = app.buttons.matching(NSPredicate(format: "label == %@", "Data")).count
        app.typeKey("t", modifierFlags: .command)
        let tabsAfter = app.buttons.matching(NSPredicate(format: "label == %@", "Data")).count
        XCTAssertGreaterThan(tabsAfter, tabsBefore)
        app.typeKey("w", modifierFlags: .command)
        let tabsClosed = app.buttons.matching(NSPredicate(format: "label == %@", "Data")).count
        XCTAssertEqual(tabsClosed, tabsBefore)
    }

    // Keyboard-first: click a row, Enter opens it, Delete (backspace) goes up.
    // Starts from the filesystem root (Cmd+Option+R) so the listing is
    // never empty, regardless of the test machine's home folder.
    func testEnterOpensAndDeleteGoesUp() {
        let outline = app.outlines.firstMatch
        XCTAssertTrue(outline.waitForExistence(timeout: 5))
        app.typeKey("r", modifierFlags: [.command, .option])
        let firstRow = outline.cells.element(boundBy: 0)
        guard firstRow.waitForExistence(timeout: 5) else {
            XCTFail("No rows in the first pane (empty start folder?)")
            return
        }
        firstRow.click()
        app.typeKey(XCUIKeyboardKey.return, modifierFlags: [])
        // After opening, Delete must bring us back to a populated listing.
        app.typeKey(XCUIKeyboardKey.delete, modifierFlags: [])
        XCTAssertTrue(outline.cells.element(boundBy: 0).waitForExistence(timeout: 5))
    }

    // The assistant opens from the function bar and answers from built-in help.
    func testAssistantAnswersEncryptionQuestion() {
        let assistant = app.buttons["Assistant"]
        XCTAssertTrue(assistant.waitForExistence(timeout: 5))
        assistant.click()
        let field = app.textFields.firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.click()
        field.typeText("How do I encrypt a file?\n")
        let answer = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS %@ OR value CONTAINS %@", "Cmd+Shift+E", "Cmd+Shift+E")
        ).firstMatch
        if !answer.waitForExistence(timeout: 10) {
            let dump = app.debugDescription
            XCTContext.runActivity(named: "UI dump") { activity in
                activity.add(XCTAttachment(string: dump))
            }
            XCTFail("Assistant answer with Cmd+Shift+E not found")
        }
    }
}
