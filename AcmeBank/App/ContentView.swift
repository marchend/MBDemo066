import SwiftUI

/// Composition root for the authenticated app shell.
///
/// Delegates the "which screen?" decision to `RootCoordinator`:
///   - `.signedOut`         \u2192 `LoginView` (shares the coordinator's
///     `LoginViewModel`, so `errorMessage` / `isSigningIn` mutations
///     land on the on-screen form).
///   - `.signedIn(session)` \u2192 `HomeDashboardView` wired to a fresh
///     `HomeDashboardViewModel(repository: StubAccountsRepository(),
///     user: SignedInUser(session:))`.
///
/// There is intentionally NO no-op `LoginView(onSignIn: { _, _, _ in })`
/// fallback here \u2014 the real Okta wiring runs through the injected
/// `AuthServicing`, and a stub closure would silently re-introduce the
/// dead-code path the prior MD050-2 review flagged.
///
/// **PR 4 change.** The signed-in branch previously presented
/// `LandingView(session:)`. It now presents `HomeDashboardView` via
/// `RootCoordinator.view(for:)`, so the dashboard is the screen the
/// app actually shows on launch when a user is signed in. The
/// `LandingView` file is retained for now (covered by its own tests)
/// but is no longer in the composition root.
struct ContentView: View {

    @ObservedObject var coordinator: AppCoordinator

    var body: some View {
        // SwiftUI re-evaluates this body whenever `coordinator.state`
        // (a `@Published`) changes, so the switch inside
        // `RootCoordinator.view(for:)` re-runs on every transition.
        RootCoordinator.view(for: coordinator)
    }
}

#Preview {
    // Preview wires a coordinator backed by a no-op auth service stub.
    // Production wiring lives in `AcmeBankApp`.
    ContentView(
        coordinator: AppCoordinator(authService: PreviewAuthService())
    )
}

/// Preview-only `AuthServicing` that never resolves. Lives next to
/// `#Preview` so it can't accidentally leak into production wiring.
private final class PreviewAuthService: AuthServicing {
    func signIn(
        username: String,
        password: String,
        keepSignedIn: Bool
    ) async throws -> UserSession {
        throw AuthError.notConfigured("Preview build.")
    }
}
