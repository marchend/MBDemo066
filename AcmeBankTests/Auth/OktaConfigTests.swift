import XCTest
@testable import AcmeBank

/// Covers `OktaConfig.load(from:)` against the four documented inputs:
/// happy path / sentinel / missing key / malformed URL.
///
/// Acceptance criterion: `OktaConfig.load()` NEVER crashes. Every assertion
/// in this file would therefore tolerate a non-crash; the explicit checks
/// here are stronger — they verify the *correct* `.notConfigured` mapping
/// for each failure mode.
final class OktaConfigTests: XCTestCase {

    // MARK: - Happy path

    func test_load_returnsConfigured_whenAllKeysHaveRealValues() {
        let info: [String: Any] = [
            "OktaIssuer":      "https://acme.okta.com/oauth2/default",
            "OktaClientId":    "0oaABCDEF1234567",
            "OktaRedirectUri": "com.acmebank.mobile:/callback",
            "OktaScopes":      "openid profile email offline_access",
        ]

        guard case let .configured(issuer, clientId, redirect, scopes) =
                OktaConfig.load(from: info) else {
            return XCTFail("Expected .configured for a fully populated Info.plist")
        }

        XCTAssertEqual(issuer.absoluteString, "https://acme.okta.com/oauth2/default")
        XCTAssertEqual(clientId, "0oaABCDEF1234567")
        XCTAssertEqual(redirect.absoluteString, "com.acmebank.mobile:/callback")
        XCTAssertEqual(scopes, ["openid", "profile", "email", "offline_access"])
    }

    func test_isConfigured_isTrue_onlyForConfiguredCase() {
        let configured = OktaConfig.configured(
            issuer: URL(string: "https://x")!,
            clientId: "id",
            redirectUri: URL(string: "x:/cb")!,
            scopes: ["openid"]
        )
        let notConfigured = OktaConfig.notConfigured(reason: "x")

        XCTAssertTrue(configured.isConfigured)
        XCTAssertFalse(notConfigured.isConfigured)
    }

    // MARK: - Sentinel detection

    func test_load_returnsNotConfigured_whenAnyValueIsSentinel() {
        let info: [String: Any] = [
            "OktaIssuer":      OktaConfig.notConfiguredSentinel,
            "OktaClientId":    "real-id",
            "OktaRedirectUri": "com.acmebank.mobile:/callback",
            "OktaScopes":      "openid",
        ]

        guard case .notConfigured = OktaConfig.load(from: info) else {
            return XCTFail("Sentinel in any field must produce .notConfigured")
        }
    }

    func test_load_returnsNotConfigured_whenAllValuesAreSentinel() {
        // This is the realistic CI shape — the pre-build script writes
        // the sentinel into all four keys when no OKTA_* env vars are set.
        let info: [String: Any] = [
            "OktaIssuer":      OktaConfig.notConfiguredSentinel,
            "OktaClientId":    OktaConfig.notConfiguredSentinel,
            "OktaRedirectUri": OktaConfig.notConfiguredSentinel,
            "OktaScopes":      OktaConfig.notConfiguredSentinel,
        ]

        guard case .notConfigured = OktaConfig.load(from: info) else {
            return XCTFail("All-sentinel must produce .notConfigured")
        }
    }

    // MARK: - Missing keys

    func test_load_returnsNotConfigured_whenAKeyIsMissing() {
        let info: [String: Any] = [
            "OktaIssuer":      "https://acme.okta.com/oauth2/default",
            "OktaClientId":    "0oaABCDEF1234567",
            // OktaRedirectUri intentionally omitted
            "OktaScopes":      "openid profile",
        ]

        guard case .notConfigured = OktaConfig.load(from: info) else {
            return XCTFail("Missing key must produce .notConfigured")
        }
    }

    func test_load_returnsNotConfigured_whenInfoDictionaryIsNil() {
        guard case .notConfigured = OktaConfig.load(from: nil) else {
            return XCTFail("nil info dictionary must produce .notConfigured")
        }
    }

    // MARK: - Malformed values

    func test_load_returnsNotConfigured_whenIssuerIsMalformedURL() {
        // URL(string:) is extremely permissive; the most reliable way
        // to make it return nil is to pass a string with a leading
        // space (whitespace is not allowed in URLs).
        let info: [String: Any] = [
            "OktaIssuer":      " not a url",
            "OktaClientId":    "0oaABCDEF1234567",
            "OktaRedirectUri": "com.acmebank.mobile:/callback",
            "OktaScopes":      "openid",
        ]

        guard case .notConfigured = OktaConfig.load(from: info) else {
            return XCTFail("Malformed issuer must produce .notConfigured")
        }
    }

    func test_load_returnsNotConfigured_whenScopesIsEmptyString() {
        let info: [String: Any] = [
            "OktaIssuer":      "https://acme.okta.com/oauth2/default",
            "OktaClientId":    "0oaABCDEF1234567",
            "OktaRedirectUri": "com.acmebank.mobile:/callback",
            "OktaScopes":      "",
        ]

        guard case .notConfigured = OktaConfig.load(from: info) else {
            return XCTFail("Empty scopes must produce .notConfigured")
        }
    }

    func test_load_neverCrashes_evenOnGarbageDictionary() {
        // The contract: load() must not crash on ANY input. Toss a
        // mix of wrong-typed values at it and confirm it lands cleanly
        // on `.notConfigured`.
        let info: [String: Any] = [
            "OktaIssuer":      42,
            "OktaClientId":    Date(),
            "OktaRedirectUri": ["nested": "array"],
            "OktaScopes":      NSNull(),
        ]

        guard case .notConfigured = OktaConfig.load(from: info) else {
            return XCTFail("Non-string values must produce .notConfigured")
        }
    }
}
