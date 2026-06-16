import Foundation
import Combine

/// ViewModel for the Login screen.
///
/// - Owns all form state (`username`, `password`, `keepSignedIn`,
///   `isPasswordVisible`, `errorMessage`, `isSigningIn`).
/// - Has zero knowledge of Okta, Keychain, or networking — the `onSignIn`
///   closure is the sole integration seam.
///
/// `errorMessage` is the source of truth for the inline banner copy. It
/// is cleared automatically on any edit to `username` or `password` so
/// the user gets immediate feedback that their next attempt is fresh.
/// Callers should set it via `handleResult(_:)` rather than building
/// copy strings ad-hoc — the four exact strings live in one place so a
/// future copy change is a single-line edit, not a grep-and-pray.
final class LoginViewModel: ObservableObject {

    // MARK: - Published state

    @Published var username: String = "" {
        didSet { errorMessage = nil }
    }
    @Published var password: String = "" {
        didSet { errorMessage = nil }
    }
    @Published var keepSignedIn: Bool = false
    @Published var isPasswordVisible: Bool = false
    @Published var errorMessage: String?

    /// `true` while a sign-in attempt is in flight. The view binds this
    /// to disable the form fields + Sign In button and show a spinner.
    /// Stays permanently `false` when the build is `.notConfigured`
    /// (there is nothing to wait on).
    @Published var isSigningIn: Bool = false

    // MARK: - Computed

    /// `true` when both `username` and `password` are non-empty AND no
    /// sign-in is currently in flight. Drives the Sign In button's
    /// enabled state.
    var isSignInEnabled: Bool {
        !username.isEmpty && !password.isEmpty && !isSigningIn
    }

    // MARK: - Integration seam

    /// Called by `signIn()` when the form is valid.
    /// Parameters: `(username, password, keepSignedIn)`.
    let onSignIn: (String, String, Bool) -> Void

    // MARK: - Init

    /// - Parameters:
    ///   - onSignIn: integration seam; defaults to a no-op so the view
    ///     can be previewed and tested in isolation.
    ///   - oktaConfig: the runtime Okta configuration. Used at init
    ///     time only — if the build is `.notConfigured` we pre-seed
    ///     `errorMessage` with the documented copy so the user sees
    ///     the inline banner immediately on launch instead of after
    ///     a doomed sign-in attempt. Defaults to `OktaConfig.load()`
    ///     for production callers.
    init(
        onSignIn: @escaping (String, String, Bool) -> Void = { _, _, _ in },
        oktaConfig: OktaConfig = OktaConfig.load()
    ) {
        self.onSignIn = onSignIn
        if case .notConfigured = oktaConfig {
            self.errorMessage = Self.copy(for: .notConfigured(""))
        }
    }

    // MARK: - Actions

    /// Submits the sign-in form.
    /// No-op when `isSignInEnabled` is `false`.
    func signIn() {
        guard isSignInEnabled else { return }
        onSignIn(username, password, keepSignedIn)
    }

    // MARK: - Error-copy mapping

    /// Maps a sign-in `Result` onto the published `errorMessage`. The
    /// four copy strings live HERE (not at the call site) so a future
    /// copy change is one diff.
    ///
    /// - `.success` clears any prior `errorMessage`.
    /// - `.failure(AuthError)` sets the documented user-facing copy.
    func handleResult(_ result: Result<UserSession, AuthError>) {
        switch result {
        case .success:
            errorMessage = nil
        case .failure(let error):
            errorMessage = Self.copy(for: error)
        }
    }

    /// Single source of truth for the four user-facing error strings.
    /// `invalidServerResponse` reuses the "couldn't reach Okta" copy
    /// because, from the user's perspective, "the server gave us back
    /// something we couldn't read" is indistinguishable from a network
    /// failure — both mean "try again later".
    static func copy(for error: AuthError) -> String {
        switch error {
        case .invalidCredentials:
            return "Incorrect username or password. Please try again."
        case .network, .invalidServerResponse:
            return "Couldn't reach Okta — check your connection and try again."
        case .mfaUnsupported:
            return "MFA is required but not supported in this build."
        case .notConfigured:
            return "Okta is not configured on this build — see README."
        }
    }
}
