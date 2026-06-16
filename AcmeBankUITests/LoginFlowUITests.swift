import XCTest
@testable import AcmeBank

/// End-to-end XCUITest for the username+password sign-in flow.
///
/// Skip-gated TWICE so CI runs stay green when no Okta env is wired:
///
/// 1. `OktaConfig.load().isConfigured` — the Expert Reference
///    `XCTSkipUnless` pattern. When the build script wrote the
///    `__OKTA_NOT_CONFIGURED__` sentinel into `Info.plist`, there is
///    no real tenant to talk to and the test reports `XCTSkip`,
///    NOT a failure.
///
/// 2. `OKTA_TEST_USERNAME` / `OKTA_TEST_PASSWORD` env vars — even
///    with a real tenant we can't drive the flow without test
///    credentials, so the same skip semantics apply.
///
/// Both skips MUST be `XCTSkipUnless` (not silent returns) so the
/// test report shows the skip reason instead of a phantom pass.
final class LoginFlowUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false

        // Gate 1: Okta configured at build time?
        try XCTSkipUnless(
            OktaConfig.load().isConfigured,
            "Okta not configured — skipping end-to-end sign-in test"
        )

        // Gate 2: test credentials in the environment?
        let env = ProcessInfo.processInfo.environment
        try XCTSkipUnless(
            env["OKTA_TEST_USERNAME"]?.isEmpty == false &&
            env["OKTA_TEST_PASSWORD"]?.isEmpty == false,
            "OKTA_TEST_USERNAME / OKTA_TEST_PASSWORD not set — skipping end-to-end sign-in test"
        )
    }

    func test_signIn_validCredentials_showsWelcomeAndEmail() throws {
        // Pull the test creds. setUpWithError already guarantees they
        // are non-empty, so a force-unwrap here is safe-by-precondition.
        let env = ProcessInfo.processInfo.environment
        let username = env["OKTA_TEST_USERNAME"]!
        let password = env["OKTA_TEST_PASSWORD"]!

        let app = XCUIApplication()
        app.launch()

        // ── Drive the login form ────────────────────────────────────────────────
        let usernameField = app.textFields["usernameField"]
        XCTAssertTrue(
            usernameField.waitForExistence(timeout: 10),
            "Username field must be present on launch"
        )
        usernameField.tap()
        usernameField.typeText(username)

        // The password field is wrapped in a SecureField. XCUITest
        // exposes it via `secureTextFields`, but the project's accessibility
        // identifier on the WRAPPER element lets us find it via either
        // collection — query the descendant tree to be robust.
        let passwordField = app.descendants(matching: .any)
            .matching(identifier: "passwordField")
            .firstMatch
        XCTAssertTrue(
            passwordField.waitForExistence(timeout: 5),
            "Password field must be present"
        )
        passwordField.tap()
        // Type into whichever real input the wrapper exposes.
        if app.secureTextFields.firstMatch.exists {
            app.secureTextFields.firstMatch.typeText(password)
        } else {
            app.textFields.element(boundBy: 1).typeText(password)
        }

        // ── Tap Sign In ─────────────────────────────────────────────────────────
        let signInButton = app.buttons["signInButton"]
        XCTAssertTrue(signInButton.exists)
        signInButton.tap()

        // ── Wait for the Welcome label on the LandingView ───────────────────────
        let welcome = app.staticTexts["welcomeLabel"]
        XCTAssertTrue(
            welcome.waitForExistence(timeout: 30),
            "Landing screen must show the Welcome label after a successful sign-in"
        )
        XCTAssertTrue(
            welcome.label.hasPrefix("Welcome,"),
            "Welcome label must start with the 'Welcome,' prefix; got: \(welcome.label)"
        )

        let emailLabel = app.staticTexts["emailLabel"]
        XCTAssertTrue(emailLabel.exists, "Landing screen must show the email label")
        XCTAssertFalse(
            emailLabel.label.isEmpty,
            "Email label must be populated from the real ID-token claim"
        )
    }
}
