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

    func test_codableRoundTrip_preservesEveryField() throws {
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

        XCTAssertEqual(decoded, original)
    }
}
