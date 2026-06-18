import Foundation

/// Identity snapshot consumed by feature screens (notably
/// `HomeDashboardView` / `HomeDashboardViewModel`) that need a
/// **first-name-shaped** view of the signed-in customer.
///
/// `UserSession` is the auth-layer source of truth (carries the
/// access token, `displayName`, and the OIDC claims). The Home
/// dashboard's greeting, however, wants `firstName` + `lastName`
/// split, and a credentials-free shape that the feature layer can
/// pass around without ever risking a token leak through a logging
/// breadcrumb. `SignedInUser` is that shape \u2014 a tiny, value-type
/// projection derived from `UserSession`.
///
/// ## Why not extend `UserSession`?
/// `UserSession` is `Codable` for round-tripping in an in-process
/// store; expanding it with derived first/last fields would have to
/// be re-derived on every decode and would tempt callers to persist
/// the projection. Keeping `SignedInUser` separate makes the data
/// flow explicit: `UserSession \u2192 SignedInUser` is a one-way
/// projection at the composition root.
public struct SignedInUser: Equatable, Hashable {

    /// Customer's first / given name. Used as the second line of the
    /// dashboard greeting (`GreetingHeader.firstName`).
    public let firstName: String

    /// Customer's last / family name. Reserved for future feature
    /// surfaces (account holder rows, transfer screens) that want
    /// the full name without re-parsing `displayName`.
    public let lastName: String

    /// Customer email. Used by future feature surfaces (profile,
    /// support contact prefill). Sourced from the `email` claim on
    /// the ID token \u2014 already validated as non-empty by
    /// `UserSession.init(idToken:accessToken:)`.
    public let email: String

    public init(firstName: String, lastName: String, email: String) {
        self.firstName = firstName
        self.lastName  = lastName
        self.email     = email
    }

    /// Projects a `UserSession` into the first-name-shaped view the
    /// feature layer wants.
    ///
    /// Splitting strategy: split `displayName` on the first run of
    /// whitespace. Everything before the split becomes `firstName`;
    /// everything after becomes `lastName`. A single-token name
    /// (`"Cher"`) yields `firstName: "Cher", lastName: ""` \u2014 the
    /// greeting layer treats an empty last name as "render only the
    /// first name", which matches the mockup.
    ///
    /// Whitespace-only or empty `displayName` falls back to
    /// `firstName == ""`; the dashboard renders an empty second line
    /// rather than crashing. `UserSession.init(idToken:accessToken:)`
    /// already rejects empty `name` claims, so this branch is
    /// defensive-only.
    public init(session: UserSession) {
        let trimmed = session.displayName.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty {
            self.firstName = ""
            self.lastName  = ""
        } else {
            // Split on the FIRST whitespace run so multi-word last
            // names ("van der Berg") survive intact on line 2.
            if let firstSpace = trimmed.firstIndex(where: { $0.isWhitespace }) {
                self.firstName = String(trimmed[..<firstSpace])
                let after = trimmed[trimmed.index(after: firstSpace)...]
                    .trimmingCharacters(in: .whitespaces)
                self.lastName = after
            } else {
                self.firstName = trimmed
                self.lastName  = ""
            }
        }
        self.email = session.email
    }
}
