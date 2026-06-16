import XCTest
@testable import AcmeBank

final class LoginViewModelTests: XCTestCase {

    /// A `.configured` OktaConfig so the init-time `.notConfigured`
    /// pre-seed doesn't pollute every test's `errorMessage`. Tests
    /// that exercise the pre-seed pass `.notConfigured` explicitly.
    private let configuredOkta: OktaConfig = .configured(
        issuer:      URL(string: "https://acme.okta.com/oauth2/default")!,
        clientId:    "0oaTEST",
        redirectUri: URL(string: "com.acmebank.mobile:/cb")!,
        scopes:      ["openid"]
    )

    private func makeVM(
        onSignIn: @escaping (String, String, Bool) -> Void = { _, _, _ in }
    ) -> LoginViewModel {
        LoginViewModel(onSignIn: onSignIn, oktaConfig: configuredOkta)
    }

    // MARK: - isSignInEnabled

    func test_isSignInEnabled_falseWhenBothEmpty() {
        let vm = makeVM()
        XCTAssertFalse(vm.isSignInEnabled)
    }

    func test_isSignInEnabled_falseWhenUsernameEmpty() {
        let vm = makeVM()
        vm.password = "secret"
        XCTAssertFalse(vm.isSignInEnabled)
    }

    func test_isSignInEnabled_falseWhenPasswordEmpty() {
        let vm = makeVM()
        vm.username = "user@example.com"
        XCTAssertFalse(vm.isSignInEnabled)
    }

    func test_isSignInEnabled_trueWhenBothNonEmpty() {
        let vm = makeVM()
        vm.username = "user@example.com"
        vm.password = "secret"
        XCTAssertTrue(vm.isSignInEnabled)
    }

    func test_isSignInEnabled_falseWhileSigningIn() {
        let vm = makeVM()
        vm.username = "u"
        vm.password = "p"
        vm.isSigningIn = true
        XCTAssertFalse(vm.isSignInEnabled,
                       "Button must be disabled mid-flight to prevent double-submit")
    }

    // MARK: - isSigningIn

    func test_isSigningIn_defaultsFalse() {
        let vm = makeVM()
        XCTAssertFalse(vm.isSigningIn)
    }

    func test_isSigningIn_canBeToggled() {
        let vm = makeVM()
        vm.isSigningIn = true
        XCTAssertTrue(vm.isSigningIn)
        vm.isSigningIn = false
        XCTAssertFalse(vm.isSigningIn)
    }

    // MARK: - isPasswordVisible

    func test_isPasswordVisible_defaultsFalse() {
        let vm = makeVM()
        XCTAssertFalse(vm.isPasswordVisible)
    }

    func test_isPasswordVisible_togglesCorrectly() {
        let vm = makeVM()
        vm.isPasswordVisible = true
        XCTAssertTrue(vm.isPasswordVisible)
        vm.isPasswordVisible = false
        XCTAssertFalse(vm.isPasswordVisible)
    }

    // MARK: - keepSignedIn

    func test_keepSignedIn_defaultsFalse() {
        let vm = makeVM()
        XCTAssertFalse(vm.keepSignedIn)
    }

    func test_keepSignedIn_togglesCorrectly() {
        let vm = makeVM()
        vm.keepSignedIn = true
        XCTAssertTrue(vm.keepSignedIn)
        vm.keepSignedIn = false
        XCTAssertFalse(vm.keepSignedIn)
    }

    // MARK: - signIn() closure invocation

    func test_signIn_invokesClosureWithCorrectArguments() {
        var capturedUsername: String?
        var capturedPassword: String?
        var capturedKeepSignedIn: Bool?

        let vm = makeVM { username, password, keep in
            capturedUsername = username
            capturedPassword = password
            capturedKeepSignedIn = keep
        }

        vm.username = "alice@example.com"
        vm.password = "hunter2"
        vm.keepSignedIn = true
        vm.signIn()

        XCTAssertEqual(capturedUsername, "alice@example.com")
        XCTAssertEqual(capturedPassword, "hunter2")
        XCTAssertEqual(capturedKeepSignedIn, true)
    }

    func test_signIn_isNoOpWhenFieldsEmpty() {
        var callCount = 0
        let vm = makeVM { _, _, _ in callCount += 1 }

        vm.signIn()

        XCTAssertEqual(callCount, 0)
    }

    func test_signIn_isNoOpWhenSigningIn() {
        var callCount = 0
        let vm = makeVM { _, _, _ in callCount += 1 }
        vm.username = "u"
        vm.password = "p"
        vm.isSigningIn = true

        vm.signIn()

        XCTAssertEqual(callCount, 0, "Must not double-submit while a call is in flight")
    }

    // MARK: - errorMessage default + clearing

    func test_errorMessage_nilByDefault_whenConfigured() {
        let vm = makeVM()
        XCTAssertNil(vm.errorMessage)
    }

    func test_errorMessage_clearsWhenUsernameChanges() {
        let vm = makeVM()
        vm.errorMessage = "Some error"
        vm.username = "new_user"
        XCTAssertNil(vm.errorMessage)
    }

    func test_errorMessage_clearsWhenPasswordChanges() {
        let vm = makeVM()
        vm.errorMessage = "Some error"
        vm.password = "new_pass"
        XCTAssertNil(vm.errorMessage)
    }

    // MARK: - handleResult — the four error copy strings

    func test_handleResult_invalidCredentials_setsExactCopy() {
        let vm = makeVM()
        vm.handleResult(.failure(.invalidCredentials))
        XCTAssertEqual(
            vm.errorMessage,
            "Incorrect username or password. Please try again."
        )
    }

    func test_handleResult_network_setsExactCopy() {
        let vm = makeVM()
        vm.handleResult(.failure(.network))
        XCTAssertEqual(
            vm.errorMessage,
            "Couldn't reach Okta — check your connection and try again."
        )
    }

    func test_handleResult_mfaUnsupported_setsExactCopy() {
        let vm = makeVM()
        vm.handleResult(.failure(.mfaUnsupported))
        XCTAssertEqual(
            vm.errorMessage,
            "MFA is required but not supported in this build."
        )
    }

    func test_handleResult_notConfigured_setsExactCopy() {
        let vm = makeVM()
        vm.handleResult(.failure(.notConfigured("ignored")))
        XCTAssertEqual(
            vm.errorMessage,
            "Okta is not configured on this build — see README."
        )
    }

    func test_handleResult_success_clearsError() {
        let vm = makeVM()
        vm.errorMessage = "Prior error"
        let session = UserSession(
            userId:        "id",
            displayName:   "n",
            email:         "e@e",
            accessToken:   "AT",
            authTimestamp: Date(),
            deviceName:    "iPhone"
        )
        vm.handleResult(.success(session))
        XCTAssertNil(vm.errorMessage)
    }

    // MARK: - .notConfigured pre-seed at init

    func test_init_preSeedsErrorMessage_whenNotConfigured() {
        let vm = LoginViewModel(
            oktaConfig: .notConfigured(reason: "Okta is not configured on this build — see README.")
        )
        XCTAssertEqual(
            vm.errorMessage,
            "Okta is not configured on this build — see README.",
            "When the build has no Okta config, the inline banner must be " +
            "visible immediately on launch — not only after a doomed attempt"
        )
    }

    func test_init_doesNotPreSeed_whenConfigured() {
        let vm = makeVM()
        XCTAssertNil(vm.errorMessage)
    }

    // MARK: - keepSignedIn passed through signIn

    func test_signIn_passesKeepSignedInFalseByDefault() {
        var capturedKeepSignedIn: Bool?
        let vm = makeVM { _, _, keep in capturedKeepSignedIn = keep }
        vm.username = "u"
        vm.password = "p"
        vm.signIn()
        XCTAssertEqual(capturedKeepSignedIn, false)
    }

    func test_signIn_passesKeepSignedInTrue_whenToggled() {
        var capturedKeepSignedIn: Bool?
        let vm = makeVM { _, _, keep in capturedKeepSignedIn = keep }
        vm.username = "u"
        vm.password = "p"
        vm.keepSignedIn = true
        vm.signIn()
        XCTAssertEqual(capturedKeepSignedIn, true)
    }
}
