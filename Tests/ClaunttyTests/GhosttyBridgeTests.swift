import XCTest
@testable import Clauntty

final class GhosttyBridgeTests: XCTestCase {

    func testPTYCreation() throws {
        let bridge = GhosttyBridge()
        let slavePath = try bridge.start()

        // Verify PTY was created
        XCTAssertFalse(slavePath.isEmpty, "Slave path should not be empty")
        XCTAssertTrue(slavePath.hasPrefix("/dev/"), "Slave path should start with /dev/")

        bridge.stop()
    }

    func testWriteToTerminal() throws {
        let bridge = GhosttyBridge()
        _ = try bridge.start()

        // Write test data - should not crash
        bridge.writeToTerminal(Data("Hello".utf8))

        bridge.stop()
    }

    func testDataCallbackSetup() throws {
        // This test verifies that the callback mechanism can be set up without crashing
        // In raw mode, data written to master doesn't echo back through slave,
        // so we can't test actual data receipt without something reading the slave
        let bridge = GhosttyBridge()

        // Set up callback
        bridge.onDataFromTerminal = { data in
            // Callback is set up correctly
        }

        let slavePath = try bridge.start()
        XCTAssertFalse(slavePath.isEmpty, "Bridge started successfully")

        // Write some data - verifies writeToTerminal doesn't crash
        bridge.writeToTerminal(Data("Test\n".utf8))

        bridge.stop()
    }

    func testWindowSize() throws {
        let bridge = GhosttyBridge()
        _ = try bridge.start()

        // Should not crash
        bridge.setWindowSize(rows: 24, cols: 80)
        bridge.setWindowSize(rows: 40, cols: 120)

        bridge.stop()
    }

    func testStopWithoutStart() {
        let bridge = GhosttyBridge()
        // Should not crash
        bridge.stop()
    }
}
