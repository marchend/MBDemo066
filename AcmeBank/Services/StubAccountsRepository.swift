import Foundation

/// In-memory `AccountsRepository` returning the three fixture accounts
/// shown on the dashboard mockup. Used by SwiftUI previews and by any
/// build that doesn't yet have the real `AccountAPIRepository` wired.
///
/// Fixture order is intentionally `[checking, savings, credit]` \u2014 the
/// dashboard renders accounts in the order the repository returns
/// them, so reordering here visibly reorders the UI.
public struct StubAccountsRepository: AccountsRepository {

    /// The three fixture accounts. Exposed `public static` so tests
    /// (and previews) can reference them without instantiating the
    /// repository.
    public static let fixtures: [Account] = [
        Account(
            id:           "acct-checking-001",
            kind:         .checking,
            displayName:  "Everyday Checking",
            maskedNumber: "\u{2022}\u{2022}\u{2022}\u{2022}4281",
            // Mockup: $4,287.43
            balance:      Decimal(string: "4287.43")!
        ),
        Account(
            id:           "acct-savings-001",
            kind:         .savings,
            displayName:  "High-Yield Savings",
            maskedNumber: "\u{2022}\u{2022}\u{2022}\u{2022}7735",
            // Mockup: $12,500.00
            balance:      Decimal(string: "12500.00")!
        ),
        Account(
            id:           "acct-credit-001",
            kind:         .credit,
            displayName:  "Acme Rewards Visa",
            maskedNumber: "\u{2022}\u{2022}\u{2022}\u{2022}9902",
            // Mockup: -$842.16 (outstanding statement balance; see
            // `Account` sign convention).
            balance:      Decimal(string: "-842.16")!
        ),
    ]

    public init() {}

    public func fetchAccounts() async throws -> [Account] {
        return Self.fixtures
    }
}
