import Foundation
#if canImport(UIKit)
import UIKit
#endif

/// The authenticated user's session, derived from a successful Okta sign-in.
///
/// Constructed by decoding the OIDC ID token's middle (claims) segment;
/// the access token is passed in alongside so the upstream networking
/// layer can attach it to authenticated requests.
///
/// `Codable` is provided so a higher-level cache (the future `AuthState`
/// store) can persist a session snapshot if it chooses to. This type
/// itself does NOT touch the Keychain — token persistence is the
/// `KeychainStore`'s responsibility.
public struct UserSession: Codable, Equatable {

    public let userId:         String
    public let displayName:    String
    public let email:          String
    public let accessToken:    String
    public let authTimestamp:  Date
    public let deviceName:     String

    // MARK: - Errors

    public enum DecodeError: Error, Equatable {
        /// The token didn't split into the standard three JWT segments
        /// (`header.claims.signature`).
        case malformedToken
        /// The claims segment wasn't valid base64url.
        case invalidBase64
        /// The claims segment decoded but wasn't valid JSON.
        case invalidJSON
        /// A required claim (`sub`, `name`, or `email`) was missing.
        case missingClaim(String)
    }

    // MARK: - JWT claims

    /// The subset of OIDC claims we care about. `auth_time` is optional
    /// (some Okta flows omit it) and falls back to `Date()` per the
    /// acceptance criteria.
    private struct IDTokenClaims: Decodable {
        let sub:       String?
        let name:      String?
        let email:     String?
        let auth_time: TimeInterval?
    }

    // MARK: - Init

    /// Memberwise init for tests / `Codable` round-trips.
    public init(
        userId:        String,
        displayName:   String,
        email:         String,
        accessToken:   String,
        authTimestamp: Date,
        deviceName:    String
    ) {
        self.userId        = userId
        self.displayName   = displayName
        self.email         = email
        self.accessToken   = accessToken
        self.authTimestamp = authTimestamp
        self.deviceName    = deviceName
    }

    /// Production init: parses an OIDC ID token and pairs the extracted
    /// identity with the (separate) access token.
    ///
    /// Throws `DecodeError` on any structural failure. NEVER force-unwraps,
    /// NEVER traps — callers (notably `OktaAuthService`) catch the typed
    /// error and surface it through `AuthError.invalidServerResponse`
    /// rather than letting it collapse to a generic "network" banner.
    public init(idToken: String, accessToken: String) throws {
        let claims = try Self.decodeClaims(from: idToken)

        guard let sub = claims.sub, !sub.isEmpty else {
            throw DecodeError.missingClaim("sub")
        }
        guard let name = claims.name, !name.isEmpty else {
            throw DecodeError.missingClaim("name")
        }
        guard let email = claims.email, !email.isEmpty else {
            throw DecodeError.missingClaim("email")
        }

        let timestamp: Date
        if let authTime = claims.auth_time {
            timestamp = Date(timeIntervalSince1970: authTime)
        } else {
            // `auth_time` is optional — fall back to "now" so a
            // session is still well-defined.
            timestamp = Date()
        }

        self.init(
            userId:        sub,
            displayName:   name,
            email:         email,
            accessToken:   accessToken,
            authTimestamp: timestamp,
            deviceName:    Self.currentDeviceName()
        )
    }

    // MARK: - JWT decoding

    /// Decodes the middle segment of a JWT into the `IDTokenClaims`
    /// struct. Pure / testable — no UI, no network.
    static func decodeClaims(from idToken: String) throws -> IDTokenClaims {
        let segments = idToken.split(separator: ".", omittingEmptySubsequences: false)
        guard segments.count == 3 else {
            throw DecodeError.malformedToken
        }
        let payloadSegment = String(segments[1])
        guard let payloadData = base64urlDecode(payloadSegment) else {
            throw DecodeError.invalidBase64
        }
        do {
            return try JSONDecoder().decode(IDTokenClaims.self, from: payloadData)
        } catch {
            throw DecodeError.invalidJSON
        }
    }

    /// Base64url → Data. JWT payloads use the URL-safe alphabet (`-_`
    /// instead of `+/`) and omit `=` padding; restore both before
    /// handing off to `Data(base64Encoded:)`.
    static func base64urlDecode(_ input: String) -> Data? {
        var s = input
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        // Re-pad to a multiple of 4.
        let remainder = s.count % 4
        if remainder > 0 {
            s.append(String(repeating: "=", count: 4 - remainder))
        }
        return Data(base64Encoded: s)
    }

    // MARK: - Device name

    /// Returns the device name on iOS, "Unknown Device" on other platforms.
    /// Extracted so tests can run without a UIKit host.
    private static func currentDeviceName() -> String {
        #if canImport(UIKit)
        return UIDevice.current.name
        #else
        return "Unknown Device"
        #endif
    }
}
