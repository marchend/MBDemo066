import Foundation
import SwiftUI

/// Top-level authentication state. The `ContentView` switches over
/// this to decide whether to present `LoginView` or `LandingView`.
enum AuthState: Equatable {
    case signedOut
    case signedIn(UserSession)
}

/// Owns the auth-state transition at the @main composition root.
///
/// Holds the injected `AuthServicing` and the injected `LoginViewModel`
/// (the same instance the `LoginView` renders against, so error copy
/// shows up on the actual on-screen form).
///
/// All state mutations happen on the main actor — the `@Published`
/// `state` drives a SwiftUI `switch`, and SwiftUI only observes
/// mutations on the main actor.
@MainActor
final class AppCoordinator: ObservableObject {

    /// The live auth state. `ContentView` switches on this.
    @Published private(set) var state: AuthState = .signedOut

    /// The login form's view model. Held here so `handleSignIn` can
    /// surface error copy on the real on-screen form and toggle the
    /// loading state, and so `ContentView` can inject the same
    /// instance into `LoginView`.
    let loginViewModel: LoginViewModel

    private let authService: AuthServicing

    // MARK: - Init

    /// Production init. Wires the supplied `AuthServicing` and builds
    /// a `LoginViewModel` whose `onSignIn` closure routes into
    /// `handleSignIn(...)`. The closure captures `self` weakly so a
    /// dangling viewModel reference (e.g. one held by a SwiftUI
    /// previewer) can't leak the coordinator.
    init(
        authService: AuthServicing,
        loginViewModel: LoginViewModel? = nil
    ) {
        self.authService = authService

        // We need to bind `onSignIn` to a method on `self`, but `self`
        // doesn't exist yet. Build the viewModel with a placeholder,
        // then re-wire it post-init. We use a class-bound holder to
        // avoid a Swift "self used before initialised" diagnostic.
        let holder = ClosureHolder()
        let vm = loginViewModel ?? LoginViewModel(
            onSignIn: { username, password, keep in
                holder.closure?(username, password, keep)
            }
        )
        self.loginViewModel = vm
        holder.closure = { [weak self] username, password, keep in
            guard let self else { return }
            Task { await self.handleSignIn(
                username: username,
                password: password,
                keepSignedIn: keep
            ) }
        }
    }

    // MARK: - Sign in / sign out

    /// Drives a single sign-in attempt.
    ///
    /// - Toggles `loginViewModel.isSigningIn` true around the call so
    ///   the view disables the form + shows the spinner.
    /// - On success: clears the error banner and transitions
    ///   `state = .signedIn(session)`.
    /// - On `AuthError`: routes through `LoginViewModel.handleResult`,
    ///   which sets the documented user-facing copy. State stays
    ///   `.signedOut`.
    /// - On any non-`AuthError` escape: defensively buckets as
    ///   `.network` so the user sees *some* banner rather than a
    ///   silent failure. (The `AuthServicing` contract says every
    ///   error is an `AuthError`, but we don't trust a future bug to
    ///   honour that.)
    func handleSignIn(
        username: String,
        password: String,
        keepSignedIn: Bool
    ) async {
        loginViewModel.isSigningIn = true
        defer { loginViewModel.isSigningIn = false }

        do {
            let session = try await authService.signIn(
                username:     username,
                password:     password,
                keepSignedIn: keepSignedIn
            )
            loginViewModel.handleResult(.success(session))
            state = .signedIn(session)
        } catch let authError as AuthError {
            loginViewModel.handleResult(.failure(authError))
            // state stays .signedOut
        } catch {
            loginViewModel.handleResult(.failure(.network))
            // state stays .signedOut
        }
    }

    /// Drops the session and returns to `.signedOut`. Token cleanup
    /// belongs to the keychain layer (future PR); this is the
    /// pure-state transition.
    ///
    /// Also resets `loginViewModel` form state so the next user on a
    /// shared device does NOT see the previous session's username,
    /// password, "Keep me signed in" choice, or stale error banner
    /// pre-filled in the form. We reset BEFORE flipping `state` so
    /// the `LoginView` re-presents with a clean form.
    func signOut() {
        loginViewModel.username      = ""
        loginViewModel.password      = ""
        loginViewModel.keepSignedIn  = false
        loginViewModel.errorMessage  = nil
        state = .signedOut
    }
}

/// Tiny class-bound holder so we can bind `LoginViewModel.onSignIn` to
/// a method on `self` from an `init` (where `self` isn't usable yet).
/// Private to this file — not part of any public API.
private final class ClosureHolder {
    var closure: ((String, String, Bool) -> Void)?
}
