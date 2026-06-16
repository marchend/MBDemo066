import SwiftUI

/// Composition root for the authenticated app shell.
///
/// Switches the visible screen on `AppCoordinator.state`:
///   - `.signedOut`        → `LoginView` (shares the coordinator's
///     `LoginViewModel`, so `errorMessage` / `isSigningIn` mutations
///     land on the on-screen form).
///   - `.signedIn(session)`→ `LandingView(session:)`.
///
/// There is intentionally NO no-op `LoginView(onSignIn: { _, _, _ in })`
/// fallback here — the real Okta wiring runs through the injected
/// `AuthServicing`, and a stub closure would silently re-introduce the
/// dead-code path the prior MD050-2 review flagged.
struct ContentView: View {

    @ObservedObject var coordinator: AppCoordinator

    var body: some View {
        switch coordinator.state {
        case .signedOut:
            LoginView(viewModel: coordinator.loginViewModel)
        case .signedIn(let session):
            LandingView(session: session)
        }
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
