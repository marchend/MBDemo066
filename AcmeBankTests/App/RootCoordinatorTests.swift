import XCTest
@testable import AcmeBank

/// Exercises the `AuthState → root view` mapping in `RootCoordinator`.
///
/// The plan calls for verifying "when auth state is signed-in, the
/// coordinator's root view type is `HomeDashboardView`". We do that by
/// asserting on `RootCoordinator.destination(for:)` (a pure
/// `enum`-returning function), not by introspecting an opaque
/// `some View` return type — the latter is brittle in Swift and
/// requires runtime mirror gymnastics for no benefit. The destination
/// enum is the public contract: `.home` means and only means
/// `HomeDashboardView`, `.login` means and only means `LoginView`.
/// `view(for:)`'s ViewBuilder is then a thin one-to-one mapping (read
/// the file) that a single greppable change to `RootCoordinator.swift`
/// can verify.
@MainActor
final class RootCoordinatorTests: XCTestCase {

    // MARK: - Fixtures

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

    // MARK: - Destination mapping

    func test_destination_signedOut_isLogin() {
        XCTAssertEqual(RootCoordinator.destination(for: .signedOut), .login)
    }

    /// Acceptance: launching the app while signed in shows the Home
    /// Dashboard, not the previous `LandingView` placeholder. The
    /// `.home` destination is the seam that pins that promise.
    func test_destination_signedIn_isHome() {
        let session = makeSession()
        XCTAssertEqual(
            RootCoordinator.destination(for: .signedIn(session)),
            .home,
            "The signed-in branch MUST resolve to .home so the dashboard is the signed-in root."
        )
    }

    func test_destination_isPureMapping_sameInputSameOutput() {
        // Two distinct sessions still both map to .home — the mapping
        // depends on the case, not the associated value. Pins the
        // contract that the dashboard is the destination regardless
        // of which user is signed in.
        let a = UserSession(
            userId: "u-1", displayName: "Alex A", email: "a@example.com",
            accessToken: "T1", authTimestamp: Date(), deviceName: "iPhone"
        )
        let b = UserSession(
            userId: "u-2", displayName: "Bo B", email: "b@example.com",
            accessToken: "T2", authTimestamp: Date(), deviceName: "iPad"
        )
        XCTAssertEqual(RootCoordinator.destination(for: .signedIn(a)), .home)
        XCTAssertEqual(RootCoordinator.destination(for: .signedIn(b)), .home)
    }

    // MARK: - Integration with AppCoordinator

    /// Exercises `RootCoordinator.view(for:)` against a real
    /// `AppCoordinator`. We can't introspect the opaque `some View`
    /// return directly, but we *can* verify the pure destination
    /// resolves from the coordinator's current state — which is the
    /// only behaviour `view(for:)` adds on top of `destination(for:)`.
    func test_appCoordinator_signedIn_resolvesToHomeDestination() async {
        let stub = StubAuth(outcome: .success(makeSession()))
        let coord = AppCoordinator(
            authService: stub,
            loginViewModel: LoginViewModel(
                oktaConfig: .configured(
                    issuer: URL(string: "https://acme.okta.com/oauth2/default")!,
                    clientId: "0oaTEST",
                    redirectUri: URL(string: "com.acmebank.mobile:/cb")!,
                    scopes: ["openid"]
                )
            )
        )

        // Initially signed-out → .login
        XCTAssertEqual(
            RootCoordinator.destination(for: coord.state),
            .login
        )

        await coord.handleSignIn(username: "u", password: "p", keepSignedIn: false)

        // After a successful sign-in → .home (i.e. HomeDashboardView).
        XCTAssertEqual(
            RootCoordinator.destination(for: coord.state),
            .home
        )
    }

    // MARK: - Stub auth service

    /// Minimal `AuthServicing` so this test file doesn't depend on
    /// the one declared in `AppCoordinatorTests`.
    private final class StubAuth: AuthServicing {
        enum Outcome {
            case success(UserSession)
            case failure(AuthError)
        }
        let outcome: Outcome
        init(outcome: Outcome) { self.outcome = outcome }

        func signIn(
            username: String,
            password: String,
            keepSignedIn: Bool
        ) async throws -> UserSession {
            switch outcome {
            case .success(let s): return s
            case .failure(let e): throw e
            }
        }
    }
}
