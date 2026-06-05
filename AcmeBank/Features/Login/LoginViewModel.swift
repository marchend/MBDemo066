import Foundation
import Combine

/// ViewModel for the Login screen.
///
/// - Owns all form state (`username`, `password`, `keepSignedIn`, `isPasswordVisible`,
///   `errorMessage`).
/// - Has zero knowledge of Okta, Keychain, or networking — the `onSignIn` closure is
///   the sole integration seam.
final class LoginViewModel: ObservableObject {

    // MARK: - Published state

    @Published var username: String = ""
    @Published var password: String = ""
    @Published var keepSignedIn: Bool = false
    @Published var isPasswordVisible: Bool = false
    @Published var errorMessage: String?

    // MARK: - Computed

    /// `true` when both `username` and `password` are non-empty.
    var isSignInEnabled: Bool {
        !username.isEmpty && !password.isEmpty
    }

    // MARK: - Integration seam

    /// Called by `signIn()` when the form is valid.
    /// Parameters: `(username, password, keepSignedIn)`.
    let onSignIn: (String, String, Bool) -> Void

    // MARK: - Init

    init(onSignIn: @escaping (String, String, Bool) -> Void = { _, _, _ in }) {
        self.onSignIn = onSignIn
    }

    // MARK: - Actions

    /// Submits the sign-in form.
    /// No-op when `isSignInEnabled` is `false`.
    func signIn() {
        guard isSignInEnabled else { return }
        onSignIn(username, password, keepSignedIn)
    }
}
