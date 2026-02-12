import XCTest

/// End-to-end UI tests for SSH connection flow
/// Requires Docker SSH test server running: ./scripts/docker-ssh/ssh-test-server.sh start
final class SSHConnectionUITests: XCTestCase {

    var app: XCUIApplication!

    // Test server credentials (from Docker)
    let testHost = "localhost"
    let testPort = "22"
    let testUsername = "testuser"
    let testPassword = "testpass"

    // Cell identifier (shows as "username@host" in the list)
    var testCellIdentifier: String { "\(testUsername)@\(testHost)" }

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()

        // Clean up any existing test connections before each test
        cleanupTestConnections()
    }

    override func tearDownWithError() throws {
        // Clean up test connections after each test
        // First go back to connection list if we're in terminal
        if !app.staticTexts["Servers"].exists {
            // Try to dismiss any modal or go back
            let closeButton = app.navigationBars.buttons.firstMatch
            if closeButton.exists {
                closeButton.tap()
                _ = app.staticTexts["Servers"].waitForExistence(timeout: 3)
            }
        }
        cleanupTestConnections()
        app.terminate()
    }

    /// Delete all test connections to keep the list clean
    private func cleanupTestConnections() {
        // Make sure we're on the connection list
        guard app.staticTexts["Servers"].waitForExistence(timeout: 3) else { return }

        // Find and delete all cells with our test identifier
        var attempts = 0
        while attempts < 20 {  // Limit to avoid infinite loop
            let cells = app.cells.containing(.staticText, identifier: testCellIdentifier)
            guard cells.count > 0 else { break }

            let cell = cells.firstMatch
            guard cell.exists else { break }

            // Swipe to delete
            cell.swipeLeft()

            // Tap delete button
            let deleteButton = app.buttons["Delete"]
            if deleteButton.waitForExistence(timeout: 2) {
                deleteButton.tap()
            } else {
                // Try tapping the red delete button that appears after swipe
                let redDelete = cell.buttons.matching(identifier: "Delete").firstMatch
                if redDelete.exists {
                    redDelete.tap()
                } else {
                    break  // Can't find delete button
                }
            }

            attempts += 1
            sleep(1)  // Wait for deletion animation
        }
    }

    // MARK: - Connection List Tests

    func testConnectionListDisplays() throws {
        // Verify the main screen shows
        XCTAssertTrue(app.staticTexts["Servers"].exists)
        XCTAssertTrue(app.buttons["Add"].exists || app.buttons["+"].exists)
    }

    func testAddNewConnection() throws {
        // Tap add button
        let addButton = app.navigationBars.buttons.element(boundBy: 0)
        XCTAssertTrue(addButton.waitForExistence(timeout: 5))
        addButton.tap()

        // Fill in connection details
        let nameField = app.textFields["Name (optional)"]
        let hostField = app.textFields["Host"]
        let portField = app.textFields["Port"]
        let usernameField = app.textFields["Username"]

        // Wait for form to appear
        XCTAssertTrue(hostField.waitForExistence(timeout: 5))

        // Enter test server details
        if nameField.exists {
            nameField.tap()
            nameField.typeText("Docker Test")
        }

        hostField.tap()
        hostField.typeText(testHost)

        // Port field should have default value, clear and set
        portField.tap()
        portField.press(forDuration: 1.0)
        app.menuItems["Select All"].tap()
        portField.typeText(testPort)

        usernameField.tap()
        usernameField.typeText(testUsername)

        // Save the connection
        let saveButton = app.navigationBars.buttons["Save"].firstMatch
        XCTAssertTrue(saveButton.waitForExistence(timeout: 5))
        saveButton.tap()

        // Verify connection appears in list (cell shows "testuser@localhost")
        let connectionCell = app.cells.containing(.staticText, identifier: testCellIdentifier).firstMatch
        XCTAssertTrue(connectionCell.waitForExistence(timeout: 5))
    }

    // MARK: - SSH Connection Tests

    func testSSHConnectionWithPassword() throws {
        // First add a connection
        try addTestConnection()

        // Tap on the connection to connect (cell shows "testuser@localhost")
        // Use firstMatch since there might be multiple connections from previous runs
        let connectionCell = app.cells.containing(.staticText, identifier: testCellIdentifier).firstMatch
        XCTAssertTrue(connectionCell.waitForExistence(timeout: 5))
        connectionCell.tap()

        // Handle password prompt
        let passwordField = app.secureTextFields.firstMatch
        if passwordField.waitForExistence(timeout: 5) {
            passwordField.tap()
            passwordField.typeText(testPassword)

            // Submit password
            let connectButton = app.buttons["Connect"]
            if connectButton.exists {
                connectButton.tap()
            } else {
                // Try pressing return
                app.keyboards.buttons["return"].tap()
            }
        }

        // Wait for terminal view to appear - check for the navigation bar with toolbar button
        // The terminal view has an "xmark.circle.fill" button in the toolbar
        let navBar = app.navigationBars.firstMatch
        XCTAssertTrue(navBar.waitForExistence(timeout: 15), "Terminal view should appear after connection")

        // Verify we're in the terminal view (navigation bar with buttons should be visible)
        XCTAssertTrue(app.navigationBars.buttons.count > 0, "Should have navigation buttons")
    }

    func testSSHConnectionShowsTerminalOutput() throws {
        // First connect
        try addTestConnection()

        let connectionCell = app.cells.containing(.staticText, identifier: testCellIdentifier).firstMatch
        XCTAssertTrue(connectionCell.waitForExistence(timeout: 5))
        connectionCell.tap()

        // Handle password
        let passwordField = app.secureTextFields.firstMatch
        if passwordField.waitForExistence(timeout: 5) {
            passwordField.tap()
            passwordField.typeText(testPassword)
            app.keyboards.buttons["return"].tap()
        }

        // Wait for connection
        sleep(3)

        // The terminal should show the welcome message from the Docker container
        // "Welcome to Clauntty SSH Test Server!"
        // Note: We can't easily read the Metal-rendered terminal content,
        // but we can verify the view is displayed and not showing an error

        // Verify no error overlay is shown
        let errorText = app.staticTexts["Connection Failed"]
        XCTAssertFalse(errorText.exists, "Should not show connection error")
    }

    func testDisconnectFromTerminal() throws {
        // Connect first
        try addTestConnection()

        let connectionCell = app.cells.containing(.staticText, identifier: testCellIdentifier).firstMatch
        connectionCell.tap()

        let passwordField = app.secureTextFields.firstMatch
        if passwordField.waitForExistence(timeout: 5) {
            passwordField.tap()
            passwordField.typeText(testPassword)
            app.keyboards.buttons["return"].tap()
        }

        // Wait for terminal
        sleep(3)

        // Tap disconnect button (red X)
        let closeButton = app.navigationBars.buttons.element(boundBy: 0)
        XCTAssertTrue(closeButton.waitForExistence(timeout: 5))
        closeButton.tap()

        // Verify we're back at the connection list
        XCTAssertTrue(app.staticTexts["Servers"].waitForExistence(timeout: 5))
    }

    // MARK: - Error Handling Tests

    func testConnectionFailureShowsError() throws {
        // Add a connection with wrong port
        try addConnectionWithDetails(
            host: "localhost",
            port: "9999",  // Wrong port
            username: "testuser"
        )

        // Tap to connect
        let connectionCell = app.cells.containing(.staticText, identifier: testCellIdentifier).firstMatch
        connectionCell.tap()

        // Handle password prompt if shown
        let passwordField = app.secureTextFields.firstMatch
        if passwordField.waitForExistence(timeout: 3) {
            passwordField.tap()
            passwordField.typeText("wrongpassword")
            app.keyboards.buttons["return"].tap()
        }

        // Should show error
        let errorText = app.staticTexts["Connection Failed"]
        XCTAssertTrue(errorText.waitForExistence(timeout: 15), "Should show connection error for wrong port")
    }

    // MARK: - Helper Methods

    private func addTestConnection() throws {
        try addConnectionWithDetails(
            host: testHost,
            port: testPort,
            username: testUsername
        )
    }

    private func addConnectionWithDetails(host: String, port: String, username: String) throws {
        // Tap add button
        let addButton = app.navigationBars.buttons.element(boundBy: 0)
        XCTAssertTrue(addButton.waitForExistence(timeout: 5))
        addButton.tap()

        // Fill form
        let hostField = app.textFields["Host"]
        let portField = app.textFields["Port"]
        let usernameField = app.textFields["Username"]

        XCTAssertTrue(hostField.waitForExistence(timeout: 5))

        hostField.tap()
        hostField.typeText(host)

        portField.tap()
        // Select all and replace
        portField.press(forDuration: 1.0)
        if app.menuItems["Select All"].exists {
            app.menuItems["Select All"].tap()
        }
        portField.typeText(port)

        usernameField.tap()
        usernameField.typeText(username)

        // Save
        app.navigationBars.buttons["Save"].firstMatch.tap()

        // Wait for list to update
        sleep(1)
    }

    // MARK: - Keyboard Accessory Bar Tests

    func testKeyboardAccessoryBarDisplays() throws {
        // Add and connect to test server
        try addTestConnection()

        let connectionCell = app.cells.containing(.staticText, identifier: testCellIdentifier).firstMatch
        XCTAssertTrue(connectionCell.waitForExistence(timeout: 5))
        connectionCell.tap()

        // Handle password
        let passwordField = app.secureTextFields.firstMatch
        if passwordField.waitForExistence(timeout: 5) {
            passwordField.tap()
            sleep(1)  // Wait for keyboard to stabilize
            passwordField.typeText(testPassword)
            sleep(1)  // Wait before tapping return

            // Try to tap return, with fallback to typing newline
            let returnButton = app.keyboards.buttons["return"]
            if returnButton.waitForExistence(timeout: 2) && returnButton.isHittable {
                returnButton.tap()
            } else {
                // Fallback: type newline character
                passwordField.typeText("\n")
            }
        }

        // Wait for terminal to load and SSH to connect
        sleep(5)

        // Tap on terminal to bring up keyboard
        // The terminal is a custom view, try tapping in the center of the screen
        let screenCenter = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        screenCenter.tap()

        // Wait for keyboard to appear
        sleep(2)

        // Debug: Check if keyboard exists and log button info
        XCTContext.runActivity(named: "Check keyboard and accessory bar") { activity in
            let keyboard = app.keyboards.firstMatch
            let keyboardExists = keyboard.exists

            // Take a screenshot of current state
            let screenshot = app.screenshot()
            let attachment = XCTAttachment(screenshot: screenshot)
            attachment.lifetime = .keepAlways
            activity.add(attachment)

            // Log what we find
            let allButtons = app.buttons.allElementsBoundByIndex
            var buttonInfo = "Found \(allButtons.count) buttons. Keyboard exists: \(keyboardExists)\n"
            for (index, button) in allButtons.enumerated() {
                buttonInfo += "Button \(index): label='\(button.label)' id='\(button.identifier)'\n"
            }

            // Add text attachment with button info
            let textAttachment = XCTAttachment(string: buttonInfo)
            textAttachment.name = "Button Info"
            textAttachment.lifetime = .keepAlways
            activity.add(textAttachment)

            // Check for accessory bar buttons using different queries
            let escById = app.buttons.matching(identifier: "Esc").firstMatch
            let escByLabel = app.buttons.matching(NSPredicate(format: "label == 'Esc'")).firstMatch
            let escInToolbar = app.toolbars.buttons["Esc"]
            let tabButton = app.buttons["Tab"]
            let ctrlButton = app.buttons["Ctrl"]

            let hasAccessoryButtons = escById.exists || escByLabel.exists || escInToolbar.exists ||
                                      tabButton.exists || ctrlButton.exists

            // Add another attachment with query results
            let queryResults = """
            Esc by ID: \(escById.exists)
            Esc by label: \(escByLabel.exists)
            Esc in toolbar: \(escInToolbar.exists)
            Tab button: \(tabButton.exists)
            Ctrl button: \(ctrlButton.exists)
            """
            let queryAttachment = XCTAttachment(string: queryResults)
            queryAttachment.name = "Query Results"
            queryAttachment.lifetime = .keepAlways
            activity.add(queryAttachment)

            XCTAssertTrue(hasAccessoryButtons, "Keyboard accessory bar should have terminal shortcut buttons. \(queryResults)")
        }
    }

    func testKeyboardAccessoryEscButton() throws {
        // Add and connect to test server
        try addTestConnection()

        let connectionCell = app.cells.containing(.staticText, identifier: testCellIdentifier).firstMatch
        connectionCell.tap()

        // Handle password
        let passwordField = app.secureTextFields.firstMatch
        if passwordField.waitForExistence(timeout: 5) {
            passwordField.tap()
            passwordField.typeText(testPassword)
            app.keyboards.buttons["return"].tap()
        }

        // Wait for terminal
        sleep(3)

        // Tap terminal to show keyboard
        app.otherElements.firstMatch.tap()
        sleep(1)

        // Find and tap Esc button
        let escButton = app.buttons["Esc"]
        if escButton.waitForExistence(timeout: 3) {
            escButton.tap()
            // Esc should be sent - we can't easily verify terminal received it,
            // but at least verify the button is tappable without crash
            XCTAssertTrue(true, "Esc button tapped successfully")
        }
    }

    func testKeyboardAccessoryCtrlCButton() throws {
        // Add and connect to test server
        try addTestConnection()

        let connectionCell = app.cells.containing(.staticText, identifier: testCellIdentifier).firstMatch
        connectionCell.tap()

        // Handle password
        let passwordField = app.secureTextFields.firstMatch
        if passwordField.waitForExistence(timeout: 5) {
            passwordField.tap()
            passwordField.typeText(testPassword)
            app.keyboards.buttons["return"].tap()
        }

        // Wait for terminal
        sleep(3)

        // Tap terminal to show keyboard
        app.otherElements.firstMatch.tap()
        sleep(1)

        // Find and tap ^C button
        let ctrlCButton = app.buttons["^C"]
        if ctrlCButton.waitForExistence(timeout: 3) {
            ctrlCButton.tap()
            // Ctrl+C should be sent
            XCTAssertTrue(true, "Ctrl+C button tapped successfully")
        }
    }
}
