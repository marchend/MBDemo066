import XCTest

/// XCUITest that proves the redesigned Home Dashboard is the screen the
/// app actually shows on launch when a user is signed in.
///
/// ## Why a launch arg, not real Okta credentials?
/// Driving the real sign-in flow requires the four `OKTA_*` build env
/// vars *and* test credentials. The dashboard wiring is independent of
/// Okta, so we use a dedicated `-uiTestSignedIn` launch arg (handled in
/// `AcmeBankApp.makeCoordinator()`) to pre-seed
/// `AppCoordinator.state = .signedIn(stubSession)`. The test then runs
/// against the real composition root (`ContentView` →
/// `RootCoordinator.view(for:)` → `HomeDashboardView`).
///
/// ## What this can (and can't) assert
/// The stub session carries an **empty access token**, so the live
/// `BFFHomeRepository.fetchHome()` does not return data in the UI-test
/// path. The chrome that always renders regardless of the load outcome
/// — the brand bar, the greeting, and the Log out control — is what we
/// pin here, plus the sign-out routing back to the login screen. The
/// data-row rendering (accounts / transactions) is covered by the unit
/// tests against `StubAccountsRepository.homeFixture`.
final class HomeDashboardUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    /// Launches the app with the signed-in test mode arg and returns
    /// the running `XCUIApplication`.
    private func launchSignedIn() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments.append("-uiTestSignedIn")
        app.launch()
        return app
    }

    // MARK: - Visibility

    func test_dashboard_isTheLaunchedScreen_whenSignedIn() {
        let app = launchSignedIn()

        // Brand-bar wordmark — the dashboard's "Acme Bank" mark.
        let wordmark = app.staticTexts["Acme Bank"]
        XCTAssertTrue(
            wordmark.waitForExistence(timeout: 10),
            "Dashboard brand-bar wordmark must be visible on launch — the app is not landing on HomeDashboardView."
        )

        // Greeting — `dashboard.greeting` combines "Welcome back," and
        // the customer's first name. With the empty-token stub session
        // the live load doesn't return a customer, so the greeting
        // falls back to the stub session's first name ("Demo").
        let greeting = app.otherElements["dashboard.greeting"]
        XCTAssertTrue(
            greeting.waitForExistence(timeout: 5),
            "Greeting element must be visible — the dashboard is not rendering the greeting header."
        )
        XCTAssertTrue(
            greeting.label.contains("Demo"),
            "Greeting must contain the stub session's firstName 'Demo'; got: \(greeting.label)"
        )

        // The Log out control is always present on the dashboard.
        let logOut = app.buttons["dashboard.logOut"]
        XCTAssertTrue(
            logOut.waitForExistence(timeout: 5),
            "Log out control must be visible on the dashboard."
        )
    }

    // MARK: - Log out routing

    func test_tappingLogOut_returnsToLogin() {
        let app = launchSignedIn()

        let logOut = app.buttons["dashboard.logOut"]
        XCTAssertTrue(
            logOut.waitForExistence(timeout: 10),
            "Log out control must be visible before tap."
        )
        logOut.tap()

        // Signing out routes back to the login screen. The brand-bar
        // wordmark belongs to the dashboard and must disappear.
        let wordmark = app.staticTexts["Acme Bank"]
        let goneFromDashboard = !wordmark.waitForExistence(timeout: 2) || !wordmark.isHittable
        XCTAssertTrue(
            goneFromDashboard,
            "After Log out, the dashboard must no longer be the visible screen."
        )
    }
}
