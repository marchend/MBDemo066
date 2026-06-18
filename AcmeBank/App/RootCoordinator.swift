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
/// hands `HomeDashboardView` its **dependencies** \u2014 a
/// `BFFHomeRepository` (wired with the session's Okta access token)
/// and the `SignedInUser` projected from the freshly-decoded
/// `UserSession` \u2014 not a pre-built `HomeDashboardViewModel`. The view
/// itself owns the ViewModel via `@StateObject`, so SwiftUI controls
/// its lifetime and a re-render of `ContentView` doesn't silently
/// rebuild it.
/// (The composition-root seam here is the only place that decides
/// which `AccountsRepository` the dashboard runs against \u2014
/// `StubAccountsRepository` is still used by previews and tests.)
///
/// ## Why pass dependencies, not the ViewModel?
/// `view(for:)` is called from `ContentView.body`, which SwiftUI
/// re-evaluates every time `AppCoordinator` publishes (including
/// future `loginViewModel.isSigningIn` / `errorMessage` mutations
/// that may occur in the signed-in branch). If this method handed
/// `HomeDashboardView` a freshly-allocated VM each time and the view
/// bound to it via `@ObservedObject`, every re-render would discard
/// the dashboard's loaded accounts and re-fire `load()`. Passing the
/// `repository:` + `user:` dependencies and letting the view's
/// `@StateObject` autoclosure init the VM once per view identity
/// fixes the lifecycle.
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
    /// - On `.signedIn(session)`: `HomeDashboardView` constructed
    ///   with its dependencies (`BFFHomeRepository` +
    ///   `SignedInUser(session:)`). The view owns its ViewModel via
    ///   `@StateObject`, so a re-evaluation of `ContentView.body`
    ///   does not blow away dashboard state.
    ///
    ///   The repository is given the session's Okta `accessToken` so it
    ///   can authenticate the BFF `GET /v1/home` call \u2014 this is the only
    ///   place the token crosses into the repository. The `UserSession`
    ///   is still projected to a token-free `SignedInUser` for the
    ///   feature/view layer, which never sees the access token directly.
    @ViewBuilder
    static func view(for coordinator: AppCoordinator) -> some View {
        switch coordinator.state {
        case .signedOut:
            LoginView(viewModel: coordinator.loginViewModel)

        case .signedIn(let session):
            HomeDashboardView(
                repository: BFFHomeRepository(accessToken: session.accessToken),
                user:       SignedInUser(session: session)
            )
        }
    }
}
