import Foundation
import OktaDirectAuth

// MARK: - Public protocol

/// What the UI layer (LoginViewModel / future AppCoordinator) depends on.
/// Constructor-injected — there is intentionally no shared singleton.
public protocol AuthServicing {
    /// Performs a username+password sign-in via Okta DirectAuth.
    ///
    /// - Returns: a populated `UserSession` on success.
    /// - Throws: `AuthError`. The Login UI does `catch let e as AuthError`,
    ///   so EVERY error path that escapes this function MUST be an
    ///   `AuthError` — otherwise the UI shows a misleading "network"
    ///   banner for a non-network failure (see lesson recorded under
    ///   MD066-2).
    func signIn(
        username: String,
        password: String,
        keepSignedIn: Bool
    ) async throws -> UserSession
}

// MARK: - Errors

/// Typed errors surfaced to the UI. New cases require a UI copy update
/// — never add an "unknown" case that the UI can't translate to a
/// meaningful banner.
public enum AuthError: Error, Equatable {
    /// Wrong username/password, locked account, expired credential, etc.
    case invalidCredentials
    /// Transport failure — Okta unreachable, timeout, TLS error.
    case network
    /// Okta returned an MFA challenge; this build doesn't yet support
    /// MFA flows (will be wired in a future PR).
    case mfaUnsupported
    /// `OktaConfig.load()` returned `.notConfigured`. The UI's
    /// "not configured" banner is the right user-facing affordance.
    case notConfigured(String)
    /// Okta returned success but the response was unreadable — typically
    /// a malformed ID token. NOT a network failure; do not show the
    /// network banner for this.
    case invalidServerResponse(String)
}

// MARK: - DirectAuth seam

/// Neutral, transport-agnostic status returned by the DirectAuth seam.
/// The production adapter (`LiveDirectAuthFlow`) translates the real
/// `okta-mobile-swift` status enum into one of these values; unit tests
/// emit them directly from a stub.
///
/// Keeping the seam in our own namespace means `AuthServiceTests` does
/// NOT need to import `OktaDirectAuth` and therefore doesn't pull the
/// SDK's network stack into the test bundle.
public enum DirectAuthStatus: Equatable {
    /// Sign-in succeeded. `refreshToken` is `nil` when the tenant
    /// didn't issue one (e.g. `offline_access` not granted).
    case success(idToken: String, accessToken: String, refreshToken: String?)
    /// Wrong credentials.
    case invalidCredentials
    /// Transport failure.
    case network
    /// MFA challenge — this build can't continue the flow yet.
    case mfaRequired
}

/// One factor in the DirectAuth flow. Today only `.password` is wired;
/// future PRs will add `.otp(_:)` etc.
public enum DirectAuthFactor: Equatable {
    case password(String)
}

/// Test seam. The production type is `LiveDirectAuthFlow` (below);
/// tests inject a stub.
public protocol DirectAuthenticationFlowProtocol {
    func start(
        _ loginHint: String,
        with factor: DirectAuthFactor
    ) async -> DirectAuthStatus
}

/// Builds a `DirectAuthenticationFlowProtocol` for a given `OktaConfig`.
/// Injected into `OktaAuthService` so tests can substitute a stub
/// factory and `OktaAuthService` itself stays testable end-to-end.
public typealias DirectAuthFlowFactory = (OktaConfig) throws -> DirectAuthenticationFlowProtocol

// MARK: - Live (production) adapter

/// Production adapter around the real `okta-mobile-swift`
/// `DirectAuthenticationFlow`. Lives in the same file as the protocol
/// so the mapping from SDK statuses → our neutral statuses is auditable
/// in one place.
final class LiveDirectAuthFlow: DirectAuthenticationFlowProtocol {

    private let flow: DirectAuthenticationFlow

    init(config: OktaConfig) throws {
        guard case let .configured(issuer, clientId, _, scopes) = config else {
            throw AuthError.notConfigured("Okta is not configured on this build — see README.")
        }
        // `okta-mobile-swift` 2.x expects scopes as a space-joined
        // string, matching the OIDC `scope` parameter format.
        self.flow = DirectAuthenticationFlow(
            issuer:   issuer,
            clientId: clientId,
            scopes:   scopes.joined(separator: " ")
        )
    }

    func start(
        _ loginHint: String,
        with factor: DirectAuthFactor
    ) async -> DirectAuthStatus {
        let sdkFactor: DirectAuthenticationFlow.PrimaryFactor
        switch factor {
        case .password(let password):
            sdkFactor = .password(password)
        }

        do {
            let status = try await flow.start(loginHint, with: sdkFactor)
            return Self.map(status: status)
        } catch {
            // The real SDK throws on transport / decoding failures.
            // We bucket all of them as `.network` here — the UI's
            // network banner is the right user-facing affordance for
            // "couldn't reach the IdP".
            return .network
        }
    }

    /// Maps the SDK's status enum onto our neutral type.
    ///
    /// `okta-mobile-swift` 2.x exposes a `DirectAuthenticationFlow.Status`
    /// enum whose cases include `.success(Token)` and several
    /// continuation cases for MFA and other secondary factors. We
    /// expose only what this PR's UI can handle (success / MFA-blocker);
    /// every other continuation collapses to `.mfaRequired` so the UI
    /// shows the "MFA not yet supported" banner instead of leaving the
    /// user stuck on a spinner.
    static func map(status: DirectAuthenticationFlow.Status) -> DirectAuthStatus {
        switch status {
        case .success(let token):
            return .success(
                idToken:      token.idToken?.rawValue ?? "",
                accessToken:  token.accessToken,
                refreshToken: token.refreshToken
            )
        default:
            // Any continuation (mfaRequired, bindingTransfer, etc.) is
            // an MFA-style challenge from this PR's perspective.
            return .mfaRequired
        }
    }
}

// MARK: - OktaAuthService

/// Concrete `AuthServicing` for Okta DirectAuth.
///
/// Two test seams via constructor injection:
/// - `keychain`: the keychain implementation (real or fake).
/// - `flowFactory`: builds the DirectAuth flow for a given config.
public final class OktaAuthService: AuthServicing {

    private let config:      OktaConfig
    private let keychain:    KeychainStoring
    private let flowFactory: DirectAuthFlowFactory

    /// Production initialiser.
    /// Defaults wire the real keychain + the real Okta SDK.
    public convenience init(
        config: OktaConfig = OktaConfig.load(),
        keychain: KeychainStoring = SystemKeychainStore()
    ) {
        self.init(
            config:      config,
            keychain:    keychain,
            flowFactory: { cfg in try LiveDirectAuthFlow(config: cfg) }
        )
    }

    /// Test initialiser. Internal so only the test bundle (via
    /// `@testable import AcmeBank`) sees it.
    init(
        config: OktaConfig,
        keychain: KeychainStoring,
        flowFactory: @escaping DirectAuthFlowFactory
    ) {
        self.config      = config
        self.keychain    = keychain
        self.flowFactory = flowFactory
    }

    // MARK: - AuthServicing

    public func signIn(
        username: String,
        password: String,
        keepSignedIn: Bool
    ) async throws -> UserSession {

        // 1. Refuse cleanly when the build has no Okta config — the UI
        //    shows the "not configured" banner instead of pretending to
        //    talk to a server.
        guard case .configured = config else {
            if case let .notConfigured(reason) = config {
                throw AuthError.notConfigured(reason)
            }
            throw AuthError.notConfigured("Okta is not configured on this build — see README.")
        }

        // 2. Build the flow. A failure here is either `.notConfigured`
        //    (already an `AuthError`) or, defensively, mapped to
        //    `.network` — we never let an unknown error type escape.
        let flow: DirectAuthenticationFlowProtocol
        do {
            flow = try flowFactory(config)
        } catch let authError as AuthError {
            throw authError
        } catch {
            throw AuthError.network
        }

        // 3. Run the DirectAuth flow. The seam never throws — it returns
        //    a neutral status — so the only way out of this `switch` is
        //    an explicit typed error.
        let status = await flow.start(username, with: .password(password))

        switch status {
        case .invalidCredentials:
            throw AuthError.invalidCredentials
        case .network:
            throw AuthError.network
        case .mfaRequired:
            throw AuthError.mfaUnsupported
        case let .success(idToken, accessToken, refreshToken):
            // 4. Decode the ID token into a UserSession. A decode
            //    failure is a SERVER-side bug, not a network failure
            //    — map to `.invalidServerResponse` so the UI doesn't
            //    show the "couldn't reach Okta" banner for a 200 OK.
            let session: UserSession
            do {
                session = try UserSession(idToken: idToken, accessToken: accessToken)
            } catch {
                throw AuthError.invalidServerResponse(
                    "Sign-in succeeded but the server response was unreadable."
                )
            }

            // 5. Persist tokens. Keychain writes are a CACHE — if they
            //    fail, the user is still signed in; the next launch
            //    just won't auto-restore. Swallow + log here, never
            //    propagate out of `signIn`.
            persist(idToken: idToken,
                    accessToken: accessToken,
                    refreshToken: refreshToken,
                    keepSignedIn: keepSignedIn)

            return session
        }
    }

    // MARK: - Token persistence

    /// Writes id+access tokens unconditionally; writes the refresh
    /// token only when `keepSignedIn` is `true`.
    ///
    /// Every write is wrapped in a local `do`/`catch` because keychain
    /// failures (notably the simulator's intermittent
    /// `errSecMissingEntitlement = -34018`) must NOT fail the sign-in.
    private func persist(
        idToken: String,
        accessToken: String,
        refreshToken: String?,
        keepSignedIn: Bool
    ) {
        do { try keychain.save(idToken,     slot: .idToken)     } catch { /* cache-only */ }
        do { try keychain.save(accessToken, slot: .accessToken) } catch { /* cache-only */ }

        if keepSignedIn, let refresh = refreshToken, !refresh.isEmpty {
            do { try keychain.save(refresh, slot: .refreshToken) } catch { /* cache-only */ }
        } else {
            // Best-effort wipe of any prior refresh token so a user
            // who unchecks "Keep me signed in" actually gets a
            // one-shot session.
            do { try keychain.delete(slot: .refreshToken) } catch { /* cache-only */ }
        }
    }
}
