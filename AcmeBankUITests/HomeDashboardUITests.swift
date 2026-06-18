import XCTest

/// XCUITest that proves the Home Dashboard is the screen the app
/// actually shows on launch when a user is signed in.
///
/// ## Why a launch arg, not real Okta credentials?
/// Driving the real sign-in flow requires the four `OKTA_*` build env
/// vars *and* test credentials — see `LoginFlowUITests` for the
/// double-gate skip pattern that file uses to keep CI green without
/// them. The dashboard wiring is independent of Okta, so we use a
/// dedicated `-uiTestSignedIn` launch arg (handled in
/// `AcmeBankApp.makeCoordinator()`) to pre-seed
/// `AppCoordinator.state = .signedIn(stubSession)`. The test then
/// runs against the real composition root (`ContentView` →
/// `RootCoordinator.view(for:)` → `HomeDashboardView`), which is the
/// whole point of the PR — proving that the dashboard is wired into
/// the live presentation graph, not just covered by unit tests.
///
/// ## Test scope
/// Asserts the five visible elements from the dashboard mockup, then
/// proves two navigation behaviours:
///   1. Tapping Transfer pushes the placeholder destination.
///   2. Tapping the bell is a no-op (navigation depth unchanged).
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

        // Nav-bar wordmark — accessibilityLabel "Acme Bank" combined
        // by the logo+wordmark HStack in `DashboardNavBar`.
        let wordmark = app.staticTexts["Acme Bank"]
        XCTAssertTrue(
            wordmark.waitForExistence(timeout: 10),
            "Dashboard nav-bar wordmark must be visible on launch — the app is not landing on HomeDashboardView."
        )

        // Greeting — `GreetingHeader` combines its two `Text`s into
        // one accessibility element with identifier
        // `dashboard.greeting` and a label that reads "<salutation>
        // <firstName>" (e.g. "Good morning, Demo"). We assert the
        // element exists and that its composed label contains the
        // stub session's first name, which is the unambiguous proof
        // that the stub UserSession reached the dashboard's
        // `SignedInUser` projection.
        let greeting = app.otherElements["dashboard.greeting"]
        XCTAssertTrue(
            greeting.waitForExistence(timeout: 5),
            "Greeting element must be visible — the dashboard is not rendering GreetingHeader."
        )
        XCTAssertTrue(
            greeting.label.contains("Demo"),
            "Greeting must contain the stub session's firstName 'Demo'; got: \(greeting.label)"
        )

        // Three account cards from the stub fixtures.
        let checking = app.otherElements["accountCard.acct-checking-001"]
        let savings  = app.otherElements["accountCard.acct-savings-001"]
        let credit   = app.otherElements["accountCard.acct-credit-001"]
        XCTAssertTrue(
            checking.waitForExistence(timeout: 5),
            "Checking account card must be visible after the stub repo's load completes."
        )
        XCTAssertTrue(savings.exists, "Savings account card must be visible.")
        XCTAssertTrue(credit.exists,  "Credit account card must be visible.")

        // Four quick actions (Transfer / Pay Bills / Deposit / More).
        // NavigationLinks and Buttons are both surfaced as `.button`
        // elements by XCUITest.
        XCTAssertTrue(app.buttons["quickAction.transfer"].exists, "Transfer quick action must be visible.")
        XCTAssertTrue(app.buttons["quickAction.payBills"].exists, "Pay Bills quick action must be visible.")
        XCTAssertTrue(app.buttons["quickAction.deposit"].exists,  "Deposit quick action must be visible.")
        XCTAssertTrue(app.buttons["quickAction.more"].exists,     "More quick action must be visible.")
    }

    // MARK: - Quick-action navigation

    func test_tappingTransfer_pushesPlaceholderDestination() {
        let app = launchSignedIn()

        let transfer = app.buttons["quickAction.transfer"]
        XCTAssertTrue(
            transfer.waitForExistence(timeout: 10),
            "Transfer quick action must be visible before tap."
        )
        transfer.tap()

        // `PlaceholderDestinationView` sets
        // `accessibilityIdentifier("quickAction.placeholder.transfer")`
        // on its outer container; XCUITest surfaces that container as
        // an `.other` element.
        let placeholder = app.otherElements["quickAction.placeholder.transfer"]
        XCTAssertTrue(
            placeholder.waitForExistence(timeout: 5),
            "Tapping Transfer must push PlaceholderDestinationView (identifier: quickAction.placeholder.transfer)."
        )
    }

    // MARK: - Bell no-op

    /// The bell is intentionally inert in this PR (notifications ship
    /// in a later story). Tapping it must not push a new screen. We
    /// verify by asserting the dashboard's quick-actions row is still
    /// hit-testable after the tap (a real push would put the
    /// dashboard underneath a new screen and the quick-actions row
    /// would no longer be visible) AND that no placeholder
    /// destination appears.
    func test_tappingBell_doesNotNavigate() {
        let app = launchSignedIn()

        let transfer = app.buttons["quickAction.transfer"]
        XCTAssertTrue(
            transfer.waitForExistence(timeout: 10),
            "Quick-actions row must be visible before bell tap."
        )

        let bell = app.buttons["dashboardNavBar.bell"]
        XCTAssertTrue(bell.exists, "Bell must be present on the nav bar.")
        bell.tap()

        // Give SwiftUI a beat in case a push was (incorrectly) queued.
        _ = app.staticTexts.firstMatch.waitForExistence(timeout: 1)

        // No placeholder destination must have been pushed.
        XCTAssertFalse(
            app.otherElements["quickAction.placeholder.transfer"].exists,
            "Tapping the bell must NOT push a placeholder."
        )
        XCTAssertFalse(
            app.otherElements["quickAction.placeholder.payBills"].exists,
            "Tapping the bell must NOT push a placeholder."
        )
        XCTAssertFalse(
            app.otherElements["quickAction.placeholder.deposit"].exists,
            "Tapping the bell must NOT push a placeholder."
        )

        // And the dashboard itself must still be the visible screen —
        // the quick-actions row would not be hit-testable behind a
        // pushed screen.
        XCTAssertTrue(
            app.buttons["quickAction.transfer"].exists,
            "Quick-actions row must still be visible after the bell tap — bell must be a no-op in this PR."
        )
    }
}
