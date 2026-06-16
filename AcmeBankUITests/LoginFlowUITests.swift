import XCTest

/// End-to-end XCUITest for the username+password sign-in flow.
///
/// Skip-gated TWICE so CI runs stay green when no Okta env is wired:
///
/// 1. `OKTA_ISSUER` env var — the env vars are propagated to the UI
///    test runner process by the Xcode scheme. We CANNOT read the
///    app's `Info.plist` from here: in a XCUITest process,
///    `Bundle.main` is the UI test runner bundle
///    (`AcmeBankUITests.xctest`), NOT `AcmeBank.app`, and the Okta
///    plist keys are only injected into the app bundle's
///    `Info.plist`. So `OktaConfig.load()` would always report
///    `.notConfigured` here and Gate 1 would always skip, even on
///    a correctly-configured CI runner. The env-var check is the
///    correct proxy for "this build was wired with a real tenant".
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

        let env = ProcessInfo.processInfo.environment

        // Gate 1: Okta configured at build time? Proxy via the env
        // var the build script also consumes — see doc comment above
        // for why we can't read the app bundle's Info.plist here.
        try XCTSkipUnless(
            env["OKTA_ISSUER"]?.isEmpty == false,
            "OKTA_ISSUER not set — skipping end-to-end sign-in test"
        )

        // Gate 2: test credentials in the environment?
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

        // ── Drive the login form ───────────────────────────────────────────
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

        // ── Tap Sign In ────────────────────────────────────────────────────
        let signInButton = app.buttons["signInButton"]
        XCTAssertTrue(signInButton.exists)
        signInButton.tap()

        // ── Wait for the Welcome label on the LandingView ─────────────────
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
