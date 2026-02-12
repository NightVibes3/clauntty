import XCTest
@testable import Clauntty

/// Unit tests for KeyboardAccessoryView - much faster than UI tests
final class KeyboardAccessoryViewTests: XCTestCase {

    var accessoryView: KeyboardAccessoryView!
    var receivedData: Data?

    override func setUp() {
        super.setUp()
        accessoryView = KeyboardAccessoryView(frame: CGRect(x: 0, y: 0, width: 400, height: 48))
        accessoryView.onKeyInput = { [weak self] data in
            self?.receivedData = data
        }
    }

    override func tearDown() {
        accessoryView = nil
        receivedData = nil
        super.tearDown()
    }

    // MARK: - Button Existence Tests

    func testAccessoryViewHasExpectedButtons() {
        // Force layout
        accessoryView.layoutIfNeeded()

        // Find buttons by iterating subviews
        let buttons = findButtons(in: accessoryView)
        let buttonTitles = buttons.compactMap { $0.title(for: .normal) }

        XCTAssertTrue(buttonTitles.contains("Esc"), "Should have Esc button")
        XCTAssertTrue(buttonTitles.contains("Tab"), "Should have Tab button")
        XCTAssertTrue(buttonTitles.contains("Ctrl"), "Should have Ctrl button")
        XCTAssertTrue(buttonTitles.contains("^C"), "Should have ^C button")
        XCTAssertTrue(buttonTitles.contains("^L"), "Should have ^L button")
        XCTAssertTrue(buttonTitles.contains("^D"), "Should have ^D button")
    }

    // MARK: - Key Output Tests

    func testEscButtonSendsEscapeSequence() {
        let escButton = findButton(titled: "Esc")
        XCTAssertNotNil(escButton, "Esc button should exist")

        escButton?.sendActions(for: .touchUpInside)

        XCTAssertEqual(receivedData, Data([0x1B]), "Esc should send 0x1B")
    }

    func testTabButtonSendsTab() {
        let tabButton = findButton(titled: "Tab")
        XCTAssertNotNil(tabButton, "Tab button should exist")

        tabButton?.sendActions(for: .touchUpInside)

        XCTAssertEqual(receivedData, Data([0x09]), "Tab should send 0x09")
    }

    func testCtrlCButtonSendsETX() {
        let ctrlCButton = findButton(titled: "^C")
        XCTAssertNotNil(ctrlCButton, "^C button should exist")

        ctrlCButton?.sendActions(for: .touchUpInside)

        XCTAssertEqual(receivedData, Data([0x03]), "^C should send ETX (0x03)")
    }

    func testCtrlLButtonSendsFormFeed() {
        let ctrlLButton = findButton(titled: "^L")
        XCTAssertNotNil(ctrlLButton, "^L button should exist")

        ctrlLButton?.sendActions(for: .touchUpInside)

        XCTAssertEqual(receivedData, Data([0x0C]), "^L should send FF (0x0C)")
    }

    func testCtrlDButtonSendsEOT() {
        let ctrlDButton = findButton(titled: "^D")
        XCTAssertNotNil(ctrlDButton, "^D button should exist")

        ctrlDButton?.sendActions(for: .touchUpInside)

        XCTAssertEqual(receivedData, Data([0x04]), "^D should send EOT (0x04)")
    }

    // MARK: - Helpers

    private func findButtons(in view: UIView) -> [UIButton] {
        var buttons: [UIButton] = []
        for subview in view.subviews {
            if let button = subview as? UIButton {
                buttons.append(button)
            }
            buttons.append(contentsOf: findButtons(in: subview))
        }
        return buttons
    }

    private func findButton(titled title: String) -> UIButton? {
        return findButtons(in: accessoryView).first { $0.title(for: .normal) == title }
    }
}
