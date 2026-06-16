import XCTest
@testable import AcmeBank

/// Exercises `OktaAuthService.signIn(...)` against a stub DirectAuth flow
/// and an in-memory keychain fake.
///
/// The four DirectAuth status branches map to:
///   .success(...)         → returns a UserSession, persists tokens
///   .invalidCredentials   → throws AuthError.invalidCredentials
///   .network              → throws AuthError.network
///   .mfaRequired          → throws AuthError.mfaUnsupported
///
/// Plus the keepSignedIn refresh-token persistence rule:
///   keepSignedIn == true  → refresh token written
///   keepSignedIn == false → refresh token NOT written (and any prior wiped)
final class AuthServiceTests: XCTestCase {

    // MARK: - Test doubles

    /// In-memory keychain. Tests assert against the `stored` dict.
    private final class FakeKeychain: KeychainStoring {
        var stored: [KeychainSlot: String] = [:]
        /// When non-nil, save() throws to simulate the simulator's
        /// `errSecMissingEntitlement` flakiness — verifies that
        /// `signIn` swallows keychain errors instead of throwing them
        /// at the UI.
        var saveError: KeychainError?

        func save(_ value: String, slot: KeychainSlot) throws {
            if let err = saveError { throw err }
            stored[slot] = value
        }
        func load(slot: KeychainSlot) throws -> String? {
            return stored[slot]
        }
        func delete(slot: KeychainSlot) throws {
            stored.removeValue(forKey: slot)
        }
    }

    /// Stub DirectAuth flow that returns a pre-programmed status.
    private final class StubFlow: DirectAuthenticationFlowProtocol {
        let result: DirectAuthStatus
        private(set) var startedLoginHint: String?
        private(set) var startedFactor: DirectAuthFactor?

        init(result: DirectAuthStatus) { self.result = result }

        func start(_ loginHint: String, with factor: DirectAuthFactor) async -> DirectAuthStatus {
            startedLoginHint = loginHint
            startedFactor    = factor
            return result
        }
    }

    // MARK: - Helpers

    /// Builds a syntactically valid ID token whose middle segment
    /// decodes to the provided claims. Reused from `UserSessionTests`'s
    /// strategy so both files exercise the same JWT shape.
    private func makeIDToken(
        sub: String = "00u123abc",
        name: String = "Alice Example",
        email: String = "alice@example.com",
        authTime: TimeInterval? = 1_700_000_000
    ) -> String {
        var claims: [String: Any] = [
            "sub":   sub,
            "name":  name,
            "email": email,
        ]
        if let t = authTime { claims["auth_time"] = t }

        let header  = "{\"alg\":\"RS256\",\"typ\":\"JWT\"}".data(using: .utf8)!
        let payload = try! JSONSerialization.data(withJSONObject: claims, options: [])
        let sig     = "signature".data(using: .utf8)!
        return [header, payload, sig]
            .map { $0.base64EncodedString()
                .replacingOccurrences(of: "+", with: "-")
                .replacingOccurrences(of: "/", with: "_")
                .replacingOccurrences(of: "=", with: "") }
            .joined(separator: ".")
    }

    /// Pre-built `.configured` OktaConfig used by every success-path test.
    private let configuredOkta: OktaConfig = .configured(
        issuer:      URL(string: "https://acme.okta.com/oauth2/default")!,
        clientId:    "0oaTEST",
        redirectUri: URL(string: "com.acmebank.mobile:/cb")!,
        scopes:      ["openid", "profile", "email", "offline_access"]
    )

    private func makeService(
        config: OktaConfig? = nil,
        keychain: FakeKeychain = FakeKeychain(),
        flow: StubFlow
    ) -> (OktaAuthService, FakeKeychain, StubFlow) {
        let cfg = config ?? configuredOkta
        let svc = OktaAuthService(
            config:   cfg,
            keychain: keychain,
            flowFactory: { _ in flow }
        )
        return (svc, keychain, flow)
    }

    // MARK: - Success branch

    func test_signIn_success_returnsPopulatedUserSession() async throws {
        let idToken = makeIDToken()
        let flow = StubFlow(result: .success(
            idToken: idToken,
            accessToken: "AT-xyz",
            refreshToken: "RT-xyz"
        ))
        let (svc, _, _) = makeService(flow: flow)

        let session = try await svc.signIn(
            username: "alice@example.com",
            password: "hunter2",
            keepSignedIn: true
        )

        XCTAssertEqual(session.userId,      "00u123abc")
        XCTAssertEqual(session.displayName, "Alice Example")
        XCTAssertEqual(session.email,       "alice@example.com")
        XCTAssertEqual(session.accessToken, "AT-xyz")
    }

    func test_signIn_success_passesUsernameAndPasswordToFlow() async throws {
        let flow = StubFlow(result: .success(
            idToken: makeIDToken(),
            accessToken: "AT",
            refreshToken: nil
        ))
        let (svc, _, _) = makeService(flow: flow)

        _ = try await svc.signIn(username: "alice@example.com", password: "p", keepSignedIn: false)

        XCTAssertEqual(flow.startedLoginHint, "alice@example.com")
        XCTAssertEqual(flow.startedFactor,    .password("p"))
    }

    func test_signIn_success_keepSignedInTrue_persistsAllThreeTokens() async throws {
        let flow = StubFlow(result: .success(
            idToken: makeIDToken(),
            accessToken: "AT-xyz",
            refreshToken: "RT-xyz"
        ))
        let (svc, keychain, _) = makeService(flow: flow)

        _ = try await svc.signIn(username: "u", password: "p", keepSignedIn: true)

        XCTAssertNotNil(keychain.stored[.idToken],     "idToken must be persisted")
        XCTAssertEqual(keychain.stored[.accessToken], "AT-xyz")
        XCTAssertEqual(keychain.stored[.refreshToken], "RT-xyz",
                       "refreshToken MUST persist when keepSignedIn=true")
    }

    func test_signIn_success_keepSignedInFalse_doesNotPersistRefreshToken() async throws {
        let flow = StubFlow(result: .success(
            idToken: makeIDToken(),
            accessToken: "AT-xyz",
            refreshToken: "RT-xyz"
        ))
        // Pre-populate a stale refresh token to verify it gets wiped.
        let keychain = FakeKeychain()
        keychain.stored[.refreshToken] = "STALE"

        let (svc, _, _) = makeService(keychain: keychain, flow: flow)

        _ = try await svc.signIn(username: "u", password: "p", keepSignedIn: false)

        XCTAssertEqual(keychain.stored[.accessToken], "AT-xyz")
        XCTAssertNil(keychain.stored[.refreshToken],
                     "refreshToken MUST NOT be present when keepSignedIn=false " +
                     "(and any prior stale value must be wiped)")
    }

    func test_signIn_success_swallowsKeychainSaveFailure() async throws {
        // Pattern-of-mistake: a keychain `errSecMissingEntitlement` on the
        // simulator must NOT fail an otherwise-successful sign-in. The
        // session is returned, the keychain remains empty (next launch
        // requires re-login, which is the documented degradation).
        let flow = StubFlow(result: .success(
            idToken: makeIDToken(),
            accessToken: "AT",
            refreshToken: "RT"
        ))
        let keychain = FakeKeychain()
        keychain.saveError = .unexpectedStatus(-34018)  // errSecMissingEntitlement

        let (svc, _, _) = makeService(keychain: keychain, flow: flow)

        // Must NOT throw — that's the whole point.
        let session = try await svc.signIn(username: "u", password: "p", keepSignedIn: true)
        XCTAssertEqual(session.userId, "00u123abc")
        XCTAssertTrue(keychain.stored.isEmpty,
                      "Stub keychain rejected every save; nothing should be stored.")
    }

    // MARK: - Failure branches

    func test_signIn_invalidCredentials_throwsAuthErrorInvalidCredentials() async {
        let flow = StubFlow(result: .invalidCredentials)
        let (svc, _, _) = makeService(flow: flow)

        do {
            _ = try await svc.signIn(username: "u", password: "wrong", keepSignedIn: false)
            XCTFail("Expected AuthError.invalidCredentials")
        } catch let err as AuthError {
            XCTAssertEqual(err, .invalidCredentials)
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    func test_signIn_network_throwsAuthErrorNetwork() async {
        let flow = StubFlow(result: .network)
        let (svc, _, _) = makeService(flow: flow)

        do {
            _ = try await svc.signIn(username: "u", password: "p", keepSignedIn: false)
            XCTFail("Expected AuthError.network")
        } catch let err as AuthError {
            XCTAssertEqual(err, .network)
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    func test_signIn_mfaRequired_throwsAuthErrorMFAUnsupported() async {
        let flow = StubFlow(result: .mfaRequired)
        let (svc, _, _) = makeService(flow: flow)

        do {
            _ = try await svc.signIn(username: "u", password: "p", keepSignedIn: false)
            XCTFail("Expected AuthError.mfaUnsupported")
        } catch let err as AuthError {
            XCTAssertEqual(err, .mfaUnsupported)
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    // MARK: - Config gating

    func test_signIn_notConfigured_throwsAuthErrorNotConfigured() async {
        let flow = StubFlow(result: .success(idToken: "should.not.be.used",
                                             accessToken: "",
                                             refreshToken: nil))
        let svc = OktaAuthService(
            config:   .notConfigured(reason: "Okta is not configured on this build — see README."),
            keychain: FakeKeychain(),
            flowFactory: { _ in flow }
        )

        do {
            _ = try await svc.signIn(username: "u", password: "p", keepSignedIn: false)
            XCTFail("Expected AuthError.notConfigured")
        } catch let err as AuthError {
            if case .notConfigured = err {} else {
                XCTFail("Expected .notConfigured, got \(err)")
            }
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    // MARK: - Bad server response

    func test_signIn_malformedIDToken_throwsInvalidServerResponse_notNetwork() async {
        // Critical lesson: a JWT decode failure after a successful SDK
        // call is NOT a network error. It must surface as a distinct
        // AuthError case so the UI doesn't show the "couldn't reach
        // Okta" banner for a 200 OK.
        let flow = StubFlow(result: .success(
            idToken: "not.a.valid.jwt.at.all", // 6 segments — malformedToken
            accessToken: "AT",
            refreshToken: nil
        ))
        let (svc, _, _) = makeService(flow: flow)

        do {
            _ = try await svc.signIn(username: "u", password: "p", keepSignedIn: false)
            XCTFail("Expected AuthError.invalidServerResponse")
        } catch let err as AuthError {
            if case .invalidServerResponse = err {} else {
                XCTFail("Expected .invalidServerResponse, got \(err)")
            }
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }
}
