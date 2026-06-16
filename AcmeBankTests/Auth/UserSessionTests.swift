import XCTest
@testable import AcmeBank

/// Covers `UserSession.init(idToken:accessToken:)` and its `DecodeError`
/// surface. The acceptance criteria call out:
///  - `sub` / `name` / `email` extracted from a real ID token
///  - `auth_time` present → `authTimestamp` matches; absent → falls back to `Date()`
///  - missing required claim → throws
///  - malformed base64 → throws
final class UserSessionTests: XCTestCase {

    // MARK: - Helpers

    /// Builds a JWT with the given claims dictionary as the middle
    /// segment. Header and signature are dummy values; the decoder
    /// only inspects the claims segment.
    private func makeJWT(claims: [String: Any]) -> String {
        let header  = base64url("{\"alg\":\"RS256\",\"typ\":\"JWT\"}".data(using: .utf8)!)
        let payload = base64url(try! JSONSerialization.data(withJSONObject: claims, options: []))
        let sig     = base64url("signature".data(using: .utf8)!)
        return "\(header).\(payload).\(sig)"
    }

    private func base64url(_ data: Data) -> String {
        // Standard base64 → URL-safe alphabet, stripped of `=` padding,
        // to match what real JWTs use.
        return data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    // MARK: - Happy paths

    func test_init_extractsSubNameEmail_fromIDToken() throws {
        let idToken = makeJWT(claims: [
            "sub":   "00u123abc",
            "name":  "Alice Example",
            "email": "alice@example.com",
            "auth_time": 1_700_000_000,
        ])

        let session = try UserSession(idToken: idToken, accessToken: "AT-xyz")

        XCTAssertEqual(session.userId,      "00u123abc")
        XCTAssertEqual(session.displayName, "Alice Example")
        XCTAssertEqual(session.email,       "alice@example.com")
        XCTAssertEqual(session.accessToken, "AT-xyz")
        XCTAssertEqual(session.authTimestamp,
                       Date(timeIntervalSince1970: 1_700_000_000))
    }

    func test_init_fallsBackToNow_whenAuthTimeIsAbsent() throws {
        let idToken = makeJWT(claims: [
            "sub":   "00u123abc",
            "name":  "Alice Example",
            "email": "alice@example.com",
            // auth_time intentionally omitted
        ])

        let before = Date()
        let session = try UserSession(idToken: idToken, accessToken: "AT-xyz")
        let after  = Date()

        // The fallback must be a sensible "now-ish" value — within the
        // window between the two reference timestamps we captured.
        XCTAssertGreaterThanOrEqual(session.authTimestamp, before.addingTimeInterval(-1))
        XCTAssertLessThanOrEqual   (session.authTimestamp, after.addingTimeInterval(1))
    }

    // MARK: - Failure paths

    func test_init_throwsMissingClaim_whenSubAbsent() {
        let idToken = makeJWT(claims: [
            "name":  "Alice Example",
            "email": "alice@example.com",
        ])

        XCTAssertThrowsError(try UserSession(idToken: idToken, accessToken: "AT")) { err in
            XCTAssertEqual(err as? UserSession.DecodeError, .missingClaim("sub"))
        }
    }

    func test_init_throwsMissingClaim_whenNameAbsent() {
        let idToken = makeJWT(claims: [
            "sub":   "00u123abc",
            "email": "alice@example.com",
        ])

        XCTAssertThrowsError(try UserSession(idToken: idToken, accessToken: "AT")) { err in
            XCTAssertEqual(err as? UserSession.DecodeError, .missingClaim("name"))
        }
    }

    func test_init_throwsMissingClaim_whenEmailAbsent() {
        let idToken = makeJWT(claims: [
            "sub":  "00u123abc",
            "name": "Alice Example",
        ])

        XCTAssertThrowsError(try UserSession(idToken: idToken, accessToken: "AT")) { err in
            XCTAssertEqual(err as? UserSession.DecodeError, .missingClaim("email"))
        }
    }

    func test_init_throwsMalformedToken_whenNotThreeSegments() {
        XCTAssertThrowsError(try UserSession(idToken: "only.two", accessToken: "AT")) { err in
            XCTAssertEqual(err as? UserSession.DecodeError, .malformedToken)
        }
    }

    func test_init_throwsInvalidBase64_whenMiddleSegmentIsGarbage() {
        // "%%%" is not valid base64 even after padding restoration.
        let idToken = "header.%%%.sig"

        XCTAssertThrowsError(try UserSession(idToken: idToken, accessToken: "AT")) { err in
            XCTAssertEqual(err as? UserSession.DecodeError, .invalidBase64)
        }
    }

    func test_init_throwsInvalidJSON_whenMiddleSegmentDecodesButIsntJSON() {
        // Valid base64url of bytes that aren't JSON.
        let nonJSON = base64url("not json".data(using: .utf8)!)
        let idToken = "header.\(nonJSON).sig"

        XCTAssertThrowsError(try UserSession(idToken: idToken, accessToken: "AT")) { err in
            XCTAssertEqual(err as? UserSession.DecodeError, .invalidJSON)
        }
    }

    // MARK: - Codable round-trip
    //
    // The `Codable` conformance is intentionally lossy: identity fields
    // round-trip, but `accessToken` and `deviceName` are deliberately
    // excluded from the encoded form so that a well-meaning caller who
    // serialises a `UserSession` (to UserDefaults, a log payload, a
    // crash breadcrumb, etc.) can't accidentally leak a live access
    // token or the user's device name (PII). See `UserSession.swift`
    // for the rationale and MD066-2 review comment 3422084530.

    func test_codableRoundTrip_preservesIdentityFields() throws {
        let original = UserSession(
            userId:        "00u123abc",
            displayName:   "Alice Example",
            email:         "alice@example.com",
            accessToken:   "AT-xyz",
            authTimestamp: Date(timeIntervalSince1970: 1_700_000_000),
            deviceName:    "Alice's iPhone"
        )

        let data    = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(UserSession.self, from: data)

        XCTAssertEqual(decoded.userId,        original.userId)
        XCTAssertEqual(decoded.displayName,   original.displayName)
        XCTAssertEqual(decoded.email,         original.email)
        XCTAssertEqual(decoded.authTimestamp, original.authTimestamp)
    }

    func test_codableRoundTrip_dropsAccessToken_toPreventLeak() throws {
        let original = UserSession(
            userId:        "00u123abc",
            displayName:   "Alice Example",
            email:         "alice@example.com",
            accessToken:   "AT-secret",
            authTimestamp: Date(timeIntervalSince1970: 1_700_000_000),
            deviceName:    "Alice's iPhone"
        )

        let data    = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(UserSession.self, from: data)

        // The access token MUST NOT survive a `Codable` round-trip —
        // it lives in the keychain, not in JSON snapshots.
        XCTAssertEqual(decoded.accessToken, "")

        // And just as importantly: the raw JSON payload must not
        // contain the secret value at all.
        let json = String(data: data, encoding: .utf8) ?? ""
        XCTAssertFalse(json.contains("AT-secret"),
                       "Access token leaked into encoded form: \(json)")
        XCTAssertFalse(json.contains("accessToken"),
                       "`accessToken` key leaked into encoded form: \(json)")
    }

    func test_codableRoundTrip_dropsDeviceName_toPreventPIILeak() throws {
        let original = UserSession(
            userId:        "00u123abc",
            displayName:   "Alice Example",
            email:         "alice@example.com",
            accessToken:   "AT-xyz",
            authTimestamp: Date(timeIntervalSince1970: 1_700_000_000),
            deviceName:    "Jane Doe's iPhone"
        )

        let data    = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(UserSession.self, from: data)

        // `UIDevice.current.name` is PII — users routinely set it to
        // their real name. It MUST NOT survive a `Codable` round-trip.
        XCTAssertEqual(decoded.deviceName, "")

        let json = String(data: data, encoding: .utf8) ?? ""
        XCTAssertFalse(json.contains("Jane Doe"),
                       "Device-name PII leaked into encoded form: \(json)")
        XCTAssertFalse(json.contains("deviceName"),
                       "`deviceName` key leaked into encoded form: \(json)")
    }
}
