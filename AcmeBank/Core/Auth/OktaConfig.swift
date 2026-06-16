import Foundation

/// Runtime representation of the Okta tenant configuration read from
/// `Info.plist`.
///
/// The build-time half of the configuration (writing the four Okta keys
/// into `AcmeBank/Info.plist` from `OKTA_*` env vars on the build machine,
/// or leaving the `__OKTA_NOT_CONFIGURED__` sentinel when those env vars
/// are unset) is implemented by the `Inject Okta Config` pre-build script
/// in `project.yml`. This enum is the runtime half: it reads those keys
/// and decides whether the app can talk to Okta or must surface a
/// "not configured" UI banner.
///
/// CRITICAL: this type NEVER calls `fatalError`, `preconditionFailure`,
/// or uses a force-unwrap. CI builds run with no `OKTA_*` env vars and
/// therefore see all four keys set to `__OKTA_NOT_CONFIGURED__`; if
/// `load()` crashed in that case the test runner couldn't even launch.
public enum OktaConfig: Equatable {

    /// Real tenant values are present and well-formed.
    case configured(
        issuer: URL,
        clientId: String,
        redirectUri: URL,
        scopes: [String]
    )

    /// Any required key is missing, contains the build-script sentinel,
    /// or is malformed. The associated reason is suitable for diagnostic
    /// logging; user-facing copy lives in the banner view, not here.
    case notConfigured(reason: String)

    // MARK: - Info.plist key names

    /// The four keys written by the `Inject Okta Config` pre-build script.
    /// Kept as an enum-of-strings so typos surface at compile time.
    public enum PlistKey {
        public static let issuer      = "OktaIssuer"
        public static let clientId    = "OktaClientId"
        public static let redirectUri = "OktaRedirectUri"
        public static let scopes      = "OktaScopes"
    }

    /// The sentinel string the pre-build script writes when an `OKTA_*`
    /// env var is unset. Documented in `project.yml` and `README.md`.
    public static let notConfiguredSentinel = "__OKTA_NOT_CONFIGURED__"

    /// Convenience: is this a usable configuration?
    public var isConfigured: Bool {
        if case .configured = self { return true }
        return false
    }

    // MARK: - Loading

    /// Loads the configuration from the main bundle's `Info.plist`.
    ///
    /// Returns `.notConfigured(reason)` (never crashes) when:
    /// - the main bundle has no `infoDictionary`, or
    /// - any of the four keys is missing, or
    /// - any of the four values equals the build-script sentinel
    ///   `__OKTA_NOT_CONFIGURED__`, or
    /// - `OktaIssuer` / `OktaRedirectUri` are not parseable as `URL`.
    public static func load() -> OktaConfig {
        load(from: Bundle.main.infoDictionary)
    }

    /// Test seam: same logic as `load()` but accepts an explicit dictionary
    /// so unit tests can drive the four code paths without mutating the
    /// host bundle.
    static func load(from infoDictionary: [String: Any]?) -> OktaConfig {
        guard let info = infoDictionary else {
            return .notConfigured(
                reason: "Okta is not configured on this build — see README."
            )
        }

        // Read all four keys as strings. Anything non-string or absent
        // collapses to a `notConfigured` result with the same generic
        // reason — the README is the source of truth for setup steps.
        guard
            let issuerString      = info[PlistKey.issuer]      as? String,
            let clientIdString    = info[PlistKey.clientId]    as? String,
            let redirectUriString = info[PlistKey.redirectUri] as? String,
            let scopesString      = info[PlistKey.scopes]      as? String
        else {
            return .notConfigured(
                reason: "Okta is not configured on this build — see README."
            )
        }

        // Sentinel detection — any field carrying the build-script
        // sentinel means at least one OKTA_* env var was unset at build
        // time.
        let allValues = [issuerString, clientIdString, redirectUriString, scopesString]
        if allValues.contains(notConfiguredSentinel) {
            return .notConfigured(
                reason: "Okta is not configured on this build — see README."
            )
        }

        // Reject empty strings the same way as the sentinel — they have
        // the same operational meaning (nothing real to talk to).
        if allValues.contains(where: { $0.isEmpty }) {
            return .notConfigured(
                reason: "Okta is not configured on this build — see README."
            )
        }

        // URL parsing — malformed values must NOT crash; surface them as
        // `.notConfigured` so the UI banner shows instead.
        guard let issuerURL = URL(string: issuerString) else {
            return .notConfigured(
                reason: "Okta is not configured on this build — see README."
            )
        }
        guard let redirectURL = URL(string: redirectUriString) else {
            return .notConfigured(
                reason: "Okta is not configured on this build — see README."
            )
        }

        // Scopes are stored as a single space-separated string in the
        // plist (matches the standard OIDC `scope` parameter format).
        // Empty / whitespace-only segments are filtered.
        let scopes = scopesString
            .split(separator: " ")
            .map { String($0) }
            .filter { !$0.isEmpty }

        if scopes.isEmpty {
            return .notConfigured(
                reason: "Okta is not configured on this build — see README."
            )
        }

        return .configured(
            issuer: issuerURL,
            clientId: clientIdString,
            redirectUri: redirectURL,
            scopes: scopes
        )
    }
}
