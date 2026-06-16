import Foundation
import Security

/// Persists the three Okta token values (id / access / refresh) in the
/// iOS data-protection keychain.
///
/// Three rules this layer enforces, all of them learned the hard way:
///
/// 1. Every query dictionary includes `kSecUseDataProtectionKeychain: true`.
///    Without it the simulator's `CODE_SIGNING_ALLOWED=NO` builds intermittently
///    return `errSecMissingEntitlement` (-34018) on `SecItemAdd`, which
///    silently destroys any flow that treats keychain writes as a hard
///    requirement.
/// 2. Keychain writes are a CACHE, not a fact-of-life. A failed write
///    only means the next launch will require re-login; it does NOT
///    invalidate a sign-in that already succeeded. Callers (`OktaAuthService`)
///    therefore log-and-ignore write failures instead of bubbling them out.
/// 3. The store is fronted by a protocol so unit tests can swap in an
///    in-memory fake. The real `SystemKeychainStore` does still get a
///    round-trip test that hits the simulator's real keychain.
public protocol KeychainStoring {
    /// Saves `value` under the given slot, overwriting any existing item.
    /// Throws `KeychainError` on failure.
    func save(_ value: String, slot: KeychainSlot) throws

    /// Loads `value` for the given slot, or `nil` if no item exists.
    /// Throws `KeychainError` on a non-`errSecItemNotFound` failure.
    func load(slot: KeychainSlot) throws -> String?

    /// Deletes the item for the given slot. Idempotent: deleting a
    /// non-existent item is NOT an error.
    func delete(slot: KeychainSlot) throws
}

/// One of the three Okta token slots. Each slot maps to a distinct
/// `kSecAttrAccount` value under a single service. The slot enum is the
/// only way to address a slot — there is intentionally no public string
/// API so a typo can't accidentally collide with a different slot.
public enum KeychainSlot: String, CaseIterable, Equatable {
    case idToken      = "acme.okta.idToken"
    case accessToken  = "acme.okta.accessToken"
    case refreshToken = "acme.okta.refreshToken"

    /// `kSecAttrAccount` value for this slot.
    public var account: String { rawValue }
}

/// Typed keychain errors. No `fatalError`, no force-unwrap.
public enum KeychainError: Error, Equatable {
    /// The value couldn't be encoded as UTF-8 data (or vice versa).
    case encodingFailed
    /// A `SecItem*` call returned a non-success status.
    case unexpectedStatus(OSStatus)
}

/// Production implementation backed by the real iOS keychain.
public final class SystemKeychainStore: KeychainStoring {

    /// `kSecAttrService` value shared by all three slots. Keeping a
    /// single service value makes it trivial to wipe every Okta token
    /// during sign-out (a future PR).
    public static let service = "com.acme.bank.okta"

    // MARK: - Test seam

    /// Hook so tests can introspect the exact query dictionary that
    /// would be sent to `SecItem*`. Tests use this to verify that
    /// `kSecUseDataProtectionKeychain` is set. Not invoked in
    /// production code paths.
    var queryInspector: (([String: Any]) -> Void)?

    public init() {}

    // MARK: - KeychainStoring

    public func save(_ value: String, slot: KeychainSlot) throws {
        guard let data = value.data(using: .utf8) else {
            throw KeychainError.encodingFailed
        }

        // Delete any prior item first so we can use `SecItemAdd` cleanly.
        // `SecItemUpdate` would work too but doubles the surface area we
        // have to keep `kSecUseDataProtectionKeychain` flagged across,
        // and the delete-then-add pattern is what the Okta sample code
        // uses too.
        try delete(slot: slot)

        var query = Self.baseQuery(for: slot)
        query[kSecValueData as String] = data
        queryInspector?(query)

        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw KeychainError.unexpectedStatus(status)
        }
    }

    public func load(slot: KeychainSlot) throws -> String? {
        var query = Self.baseQuery(for: slot)
        query[kSecReturnData as String]  = true
        query[kSecMatchLimit as String]  = kSecMatchLimitOne
        queryInspector?(query)

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        switch status {
        case errSecSuccess:
            guard let data = result as? Data,
                  let value = String(data: data, encoding: .utf8) else {
                throw KeychainError.encodingFailed
            }
            return value
        case errSecItemNotFound:
            return nil
        default:
            throw KeychainError.unexpectedStatus(status)
        }
    }

    public func delete(slot: KeychainSlot) throws {
        let query = Self.baseQuery(for: slot)
        queryInspector?(query)

        let status = SecItemDelete(query as CFDictionary)
        // Idempotent: not-found is not an error.
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.unexpectedStatus(status)
        }
    }

    // MARK: - Query shape

    /// The baseline query dictionary every operation builds on. Every
    /// callsite goes through this helper so the data-protection flag
    /// can't drift away from any individual `SecItem*` call.
    static func baseQuery(for slot: KeychainSlot) -> [String: Any] {
        return [
            kSecClass as String:                     kSecClassGenericPassword,
            kSecAttrService as String:               service,
            kSecAttrAccount as String:               slot.account,
            kSecUseDataProtectionKeychain as String: true,
        ]
    }
}
