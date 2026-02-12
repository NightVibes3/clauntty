import XCTest
@testable import Clauntty

@MainActor
final class GhosttyAppTests: XCTestCase {

    func testGhosttyAppInitialization() {
        // GhosttyGlobal.initialize() is called by the app host
        // so we can directly test GhosttyApp creation
        let app = GhosttyApp()

        // Should initialize to ready state (not error or loading)
        XCTAssertEqual(app.readiness, .ready, "GhosttyApp should be ready after initialization")

        // ghostty_app_t should be non-nil
        XCTAssertNotNil(app.app, "ghostty_app_t should be created")
    }

    func testGhosttyAppReadinessStates() {
        // Verify the readiness enum has expected cases
        let loading = GhosttyApp.Readiness.loading
        let error = GhosttyApp.Readiness.error
        let ready = GhosttyApp.Readiness.ready

        XCTAssertEqual(loading.rawValue, "loading")
        XCTAssertEqual(error.rawValue, "error")
        XCTAssertEqual(ready.rawValue, "ready")
    }

    func testGhosttyAppTick() {
        let app = GhosttyApp()

        // appTick should not crash even when called multiple times
        app.appTick()
        app.appTick()
        app.appTick()

        // App should still be ready
        XCTAssertEqual(app.readiness, .ready)
    }
}
