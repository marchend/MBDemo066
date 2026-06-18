import SwiftUI

/// Decides which screen the app presents from `AppCoordinator.state`,
/// and builds that screen with its dependencies wired.
///
/// ## Why a separate type from `AppCoordinator`?
/// `AppCoordinator` owns the auth-state machine (the data). Picking a
/// *view* off that state \u2014 and constructing the view-model graph the
/// view needs \u2014 is a presentation concern that benefits from being
/// tested without spinning up a real `AuthServicing` graph.
/// `RootCoordinator` is that presentation seam: a stateless
/// `enum`-namespaced builder so a `RootCoordinatorTests` can assert
/// "given `.signedIn(session)`, the destination is `.home`" without
/// instantiating the full `AppCoordinator`.
///
/// ## Wiring
/// `ContentView` calls `RootCoordinator.view(for: coordinator)` to
/// produce the screen for the current state. The signed-in branch
/// constructs a `HomeDashboardViewModel` backed by
/// `StubAccountsRepository()` and the `SignedInUser` projected from
/// the freshly-decoded `UserSession`. (The repository will be swapped
/// for the real `AccountAPIRepository` in a future PR \u2014 the
/// composition-root seam here is the only place that needs to
/// change.)
///
/// `HomeDashboardView` already wraps its content in its own
/// `NavigationStack` (so the inline `.navigationDestination(for:)`
/// registered for quick actions resolves), so we deliberately do NOT
/// double-wrap here.
@MainActor
enum RootCoordinator {

    /// Discriminator for the active root destination. Returned by
    /// `destination(for:)` so tests can assert which screen the
    /// composition root resolves to without instantiating a SwiftUI
    /// view (opaque `some View` returns are awkward to introspect in
    /// tests).
    enum Destination: Equatable {
        /// The signed-out branch \u2014 renders `LoginView`.
        case login
        /// The signed-in branch \u2014 renders `HomeDashboardView`.
        case home
    }

    /// Pure mapping from auth state to root destination. Used by
    /// `RootCoordinatorTests` to verify the signed-in branch resolves
    /// to `.home` (i.e. to `HomeDashboardView`, not the prior
    /// `LandingView` placeholder).
    static func destination(for state: AuthState) -> Destination {
        switch state {
        case .signedOut:    return .login
        case .signedIn:     return .home
        }
    }

    /// Builds the root view for the given coordinator's current
    /// state. Called from `ContentView`'s `body`.
    ///
    /// - On `.signedOut`: `LoginView` bound to the same
    ///   `LoginViewModel` the coordinator owns, so error copy /
    ///   spinner state set inside `handleSignIn(...)` land on the
    ///   live form.
    /// - On `.signedIn(session)`: `HomeDashboardView` wired to a
    ///   freshly-constructed `HomeDashboardViewModel`. The session's
    ///   `UserSession` is projected to a `SignedInUser` here \u2014 the
    ///   feature layer never sees the access token.
    @ViewBuilder
    static func view(for coordinator: AppCoordinator) -> some View {
        switch coordinator.state {
        case .signedOut:
            LoginView(viewModel: coordinator.loginViewModel)

        case .signedIn(let session):
            HomeDashboardView(
                viewModel: HomeDashboardViewModel(
                    repository: StubAccountsRepository(),
                    user:       SignedInUser(session: session)
                )
            )
        }
    }
}
