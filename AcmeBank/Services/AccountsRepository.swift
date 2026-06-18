import Foundation

/// What the dashboard (and any future feature) depends on for the list
/// of accounts. Constructor-injected \u2014 there is intentionally no shared
/// singleton.
///
/// ## Async / throws
/// `fetchAccounts()` is `async throws` because the production
/// implementation will hit the network. The stub returns synchronously
/// under the hood but still satisfies the signature so the call site is
/// identical across stub and real implementations.
public protocol AccountsRepository {
    /// Returns every account visible to the signed-in customer, in
    /// dashboard display order (the repository decides the order \u2014 the
    /// UI must not re-sort, so that the fixture order matches the
    /// mockup).
    func fetchAccounts() async throws -> [Account]
}
