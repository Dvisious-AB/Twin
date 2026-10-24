import AppKit
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
        // Count tab chips by accessibility identifier — folder-name
        // labels vary with the restored session.
        let tabChips = app.buttons.matching(identifier: "paneTab")
        let tabsBefore = tabChips.count
        app.typeKey("t", modifierFlags: .command)
        XCTAssertGreaterThan(tabChips.count, tabsBefore)
        app.typeKey("w", modifierFlags: .command)
        XCTAssertEqual(tabChips.count, tabsBefore)
    }

    // Arrow keys move the selection without any mouse click first
    // (regression: pane root held focus, Table never saw the keys).
    func testArrowKeysMoveSelection() throws {
        let outline = app.outlines.firstMatch
        XCTAssertTrue(outline.cells.element(boundBy: 0).waitForExistence(timeout: 10))
        // Deterministic listing: filesystem root.
        app.typeKey("r", modifierFlags: [.command, .option])
        XCTAssertTrue(outline.cells.element(boundBy: 0).waitForExistence(timeout: 10))

        func selectedIndex() -> Int? {
            (0..<outline.cells.count).first { outline.cells.element(boundBy: $0).isSelected }
        }
        // Movement, not exact steps: XCUITest key events can repeat
        // (holding ↓ scrolls in real use too). The regression being
        // pinned is "arrows do nothing without a prior mouse click".
        let before = try XCTUnwrap(selectedIndex())
        app.typeKey(XCUIKeyboardKey.downArrow, modifierFlags: [])
        let afterDown = try XCTUnwrap(selectedIndex())
        XCTAssertGreaterThan(afterDown, before)
        app.typeKey(XCUIKeyboardKey.upArrow, modifierFlags: [])
        let afterUp = try XCTUnwrap(selectedIndex())
        XCTAssertLessThan(afterUp, afterDown)
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

    // NOTE: drag-and-drop has no E2E test — XCUITest/CGEvent synthetic
    // drags initiate (drag image observed) but never complete a drop
    // into the SwiftUI Table panes in this environment. The list-view
    // drag source (.draggable) and the drop path are covered by unit
    // tests of the underlying services; end-to-end proof needs a real
    // mouse (issue #12).

    // The assistant opens from the function bar's More menu and answers from built-in help.
    // Timeouts are generous: cold CI runners take >100 s for first launch
    // (observed 122 s for a sibling test) while local runs take ~8 s.
    func testAssistantAnswersEncryptionQuestion() throws {
        XCTAssertTrue(app.windows.firstMatch.waitForExistence(timeout: 30))
        // Readiness gate proven on CI (this button appears once the
        // function bar is in the AX tree; cold first render is slow).
        XCTAssertTrue(app.buttons["F5 Copy"].waitForExistence(timeout: 120))
        // SwiftUI Menu surfaces as different AX types across macOS
        // versions (menuButton locally, popUpButton on the CI runner),
        // so poll the candidate types once the bar is rendered.
        // firstMatch keeps the element unambiguous even when restored
        // extra windows duplicate the function bar.
        var more: XCUIElement?
        let deadline = Date().addingTimeInterval(30)
        while more == nil, Date() < deadline {
            more = [app.menuButtons, app.popUpButtons, app.buttons]
                .map { $0.matching(NSPredicate(format: "title == 'More' OR label == 'More'")).firstMatch }
                .first { $0.exists }
            if more == nil { Thread.sleep(forTimeInterval: 1) }
        }
        let moreButton = try XCTUnwrap(more, "More menu button not found in function bar")
        moreButton.click()
        // "Assistant…" also exists in the Commands menu bar menu, so
        // match within the just-opened function-bar menu, first match.
        let assistant = app.menuItems
            .matching(NSPredicate(format: "title == 'Assistant…'")).firstMatch
        XCTAssertTrue(assistant.waitForExistence(timeout: 60))
        assistant.click()
        let field = app.textFields.firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 60))
        field.click()
        field.typeText("How do I encrypt a file?\n")
        let answer = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS %@ OR value CONTAINS %@", "Cmd+Shift+E", "Cmd+Shift+E")
        ).firstMatch
        if !answer.waitForExistence(timeout: 60) {
            let dump = app.debugDescription
            XCTContext.runActivity(named: "UI dump") { activity in
                activity.add(XCTAttachment(string: dump))
            }
            XCTFail("Assistant answer with Cmd+Shift+E not found")
        }
    }
}

extension TwinUITests {
    // F3 viewer: a Markdown fixture in the home folder opens in the
    // built-in viewer (name + Edit affordance prove the sheet).
    func testF3OpensBuiltinViewer() throws {
        // Fixture in the test runner's tmp dir (the runner is
        // sandboxed and can't write shared folders), delivered to
        // Twin through its own twin://open?path= deep link — the
        // same public path FinderSync's "Open in Twin" uses.
        let folder = FileManager.default.temporaryDirectory
            .appendingPathComponent("TwinViewerFixture")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let file = folder.appendingPathComponent("viewme.md")
        try "# Hello Twin\n\nViewer fixture.\n".write(to: file, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: folder) }

        let encoded = folder.path.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? folder.path
        XCTAssertTrue(NSWorkspace.shared.open(URL(string: "twin://open?path=\(encoded)")!))
        // Table cells carry no AX label; the name is a text inside.
        let fileText = app.staticTexts.matching(
            NSPredicate(format: "label == %@ OR value == %@", "viewme.md", "viewme.md")).firstMatch
        XCTAssertTrue(fileText.waitForExistence(timeout: 15))
        fileText.click()
        // Restored windows can duplicate the function bar.
        let f3 = app.buttons["F3 View"].firstMatch
        XCTAssertTrue(f3.waitForExistence(timeout: 10))
        f3.click()
        // The viewer sheet shows the file name and offers Edit (F4 path).
        let viewerTitle = app.staticTexts.matching(NSPredicate(format: "label == %@ OR value == %@", "viewme.md", "viewme.md")).firstMatch
        XCTAssertTrue(viewerTitle.waitForExistence(timeout: 15))
        XCTAssertTrue(app.buttons["Edit"].firstMatch.exists)
        app.typeKey(XCUIKeyboardKey.escape, modifierFlags: [])
    }

    // The file-type guide opens from the Files menu and shows all steps.
    func testFileTypeHandlersGuideOpens() {
        app.menuBars.menuBarItems["Files"].click()
        let item = app.menuBars.menuItems["File Type Handlers…"]
        XCTAssertTrue(item.waitForExistence(timeout: 10))
        item.click()
        XCTAssertTrue(app.staticTexts["1. Choose a file type"].waitForExistence(timeout: 15))
        XCTAssertTrue(app.staticTexts["2. View (F3) — visar filen"].exists)
        XCTAssertTrue(app.buttons["Save"].exists)
        XCTAssertTrue(app.buttons["Add Custom Handler"].exists)
        app.buttons["Done"].click()
    }
}
