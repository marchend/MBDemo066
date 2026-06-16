import XCTest
@testable import AcmeBank

/// Exercises `AppCoordinator`'s state machine against a stub
/// `AuthServicing`.
///
/// State transitions under test:
///   .signedOut  ──signIn-success──▶  .signedIn(session)
///   .signedOut  ──signIn-failure──▶  .signedOut  (+ errorMessage set)
///   .signedIn   ──signOut─────────▶  .signedOut
@MainActor
final class AppCoordinatorTests: XCTestCase {

    // MARK: - Stub

    /// Stub `AuthServicing` that returns a pre-programmed result.
    private final class StubAuthService: AuthServicing {
        enum Outcome {
            case success(UserSession)
            case failure(AuthError)
        }
        let outcome: Outcome
        private(set) var capturedUsername: String?
        private(set) var capturedPassword: String?
        private(set) var capturedKeepSignedIn: Bool?

        init(outcome: Outcome) { self.outcome = outcome }

        func signIn(
            username: String,
            password: String,
            keepSignedIn: Bool
        ) async throws -> UserSession {
            capturedUsername     = username
            capturedPassword     = password
            capturedKeepSignedIn = keepSignedIn
            switch outcome {
            case .success(let s): return s
            case .failure(let e): throw e
            }
        }
    }

    // MARK: - Helpers

    private func makeSession() -> UserSession {
        UserSession(
            userId:        "00u123",
            displayName:   "Alice Example",
            email:         "alice@example.com",
            accessToken:   "AT",
            authTimestamp: Date(timeIntervalSince1970: 1_700_000_000),
            deviceName:    "iPhone Test"
        )
    }

    /// Builds a coordinator whose `LoginViewModel` is constructed with
    /// a `.configured` Okta config so the init-time pre-seed doesn't
    /// pollute `errorMessage` in tests that don't care about it.
    private func makeCoordinator(authService: AuthServicing) -> AppCoordinator {
        let vm = LoginViewModel(
            oktaConfig: .configured(
                issuer: URL(string: "https://acme.okta.com/oauth2/default")!,
                clientId: "0oaTEST",
                redirectUri: URL(string: "com.acmebank.mobile:/cb")!,
                scopes: ["openid"]
            )
        )
        return AppCoordinator(authService: authService, loginViewModel: vm)
    }

    // MARK: - Initial state

    func test_initialState_isSignedOut() {
        let coord = makeCoordinator(
            authService: StubAuthService(outcome: .failure(.network))
        )
        XCTAssertEqual(coord.state, .signedOut)
    }

    // MARK: - Sign-in success

    func test_handleSignIn_success_transitionsToSignedIn() async {
        let session = makeSession()
        let stub = StubAuthService(outcome: .success(session))
        let coord = makeCoordinator(authService: stub)

        await coord.handleSignIn(
            username: "alice@example.com",
            password: "hunter2",
            keepSignedIn: true
        )

        XCTAssertEqual(coord.state, .signedIn(session))
        XCTAssertNil(coord.loginViewModel.errorMessage,
                     "Successful sign-in must clear the error banner")
        XCTAssertFalse(coord.loginViewModel.isSigningIn,
                       "isSigningIn must be cleared after the call")
    }

    func test_handleSignIn_success_passesCredentialsAndKeepSignedInThrough() async {
        let stub = StubAuthService(outcome: .success(makeSession()))
        let coord = makeCoordinator(authService: stub)

        await coord.handleSignIn(
            username: "alice@example.com",
            password: "hunter2",
            keepSignedIn: true
        )

        XCTAssertEqual(stub.capturedUsername, "alice@example.com")
        XCTAssertEqual(stub.capturedPassword, "hunter2")
        XCTAssertEqual(stub.capturedKeepSignedIn, true,
                       "keepSignedIn flag MUST propagate to the auth service " +
                       "(AC6: controls refresh-token persistence)")
    }

    // MARK: - Sign-in failure

    func test_handleSignIn_invalidCredentials_staysSignedOutAndSetsErrorCopy() async {
        let stub = StubAuthService(outcome: .failure(.invalidCredentials))
        let coord = makeCoordinator(authService: stub)

        await coord.handleSignIn(username: "u", password: "wrong", keepSignedIn: false)

        XCTAssertEqual(coord.state, .signedOut,
                       "A failed sign-in must NOT transition to .signedIn")
        XCTAssertEqual(
            coord.loginViewModel.errorMessage,
            "Incorrect username or password. Please try again."
        )
    }

    func test_handleSignIn_networkFailure_staysSignedOutAndSetsErrorCopy() async {
        let stub = StubAuthService(outcome: .failure(.network))
        let coord = makeCoordinator(authService: stub)

        await coord.handleSignIn(username: "u", password: "p", keepSignedIn: false)

        XCTAssertEqual(coord.state, .signedOut)
        XCTAssertEqual(
            coord.loginViewModel.errorMessage,
            "Couldn't reach Okta — check your connection and try again."
        )
    }

    func test_handleSignIn_mfaFailure_staysSignedOutAndSetsErrorCopy() async {
        let stub = StubAuthService(outcome: .failure(.mfaUnsupported))
        let coord = makeCoordinator(authService: stub)

        await coord.handleSignIn(username: "u", password: "p", keepSignedIn: false)

        XCTAssertEqual(coord.state, .signedOut)
        XCTAssertEqual(
            coord.loginViewModel.errorMessage,
            "MFA is required but not supported in this build."
        )
    }

    // MARK: - isSigningIn loading state

    func test_handleSignIn_clearsIsSigningInOnFailure() async {
        let stub = StubAuthService(outcome: .failure(.network))
        let coord = makeCoordinator(authService: stub)

        await coord.handleSignIn(username: "u", password: "p", keepSignedIn: false)

        XCTAssertFalse(coord.loginViewModel.isSigningIn,
                       "isSigningIn must be cleared after a failed call")
    }

    // MARK: - Sign out

    func test_signOut_transitionsBackToSignedOut() async {
        let stub = StubAuthService(outcome: .success(makeSession()))
        let coord = makeCoordinator(authService: stub)

        await coord.handleSignIn(username: "u", password: "p", keepSignedIn: false)
        XCTAssertNotEqual(coord.state, .signedOut)

        coord.signOut()
        XCTAssertEqual(coord.state, .signedOut)
    }
}
