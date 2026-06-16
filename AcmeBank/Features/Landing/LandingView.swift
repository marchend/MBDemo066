import SwiftUI

/// Post-sign-in landing screen.
///
/// Intentionally minimal: a Welcome greeting and the user's email
/// pulled from the freshly-decoded `UserSession`. No second network
/// call — the values come from the ID token claims the auth layer
/// already decoded.
struct LandingView: View {

    let session: UserSession

    var body: some View {
        VStack(spacing: 8) {
            Text("Welcome, \(session.displayName)")
                .font(.title)
                .accessibilityIdentifier("welcomeLabel")

            Text(session.email)
                .foregroundStyle(.secondary)
                .accessibilityIdentifier("emailLabel")
        }
        .padding()
    }
}
