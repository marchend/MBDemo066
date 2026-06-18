import Foundation

/// A single banking product owned by the signed-in customer.
///
/// Pure value type \u2014 no UI, no networking, no formatting. The dashboard
/// (and any future feature) consumes `[Account]` from an
/// `AccountsRepository` and renders the `balance` via `CurrencyFormatter`.
///
/// ## Why `Decimal` for `balance`
/// Money is base-10 by definition; `Double` introduces binary-floating
/// rounding error that compounds across transactions. `Decimal` keeps
/// the exact value the server sent and matches Apple's recommendation
/// for currency arithmetic.
///
/// ## Sign convention for `balance`
/// - Checking / savings: `balance >= 0` (an overdrawn checking account
///   would surface as a negative balance, but the fixtures don't model
///   that case).
/// - Credit: `balance` is the *outstanding statement balance* expressed
///   as a NEGATIVE number, matching the "what you owe" convention used
///   on the dashboard mockup (e.g. `-$842.16`). `CurrencyFormatter`
///   renders that with a leading minus.
public struct Account: Equatable, Hashable, Codable, Identifiable {

    /// Stable identifier (server-issued in production, fixture-issued
    /// in `StubAccountsRepository`). String so it round-trips a JSON
    /// payload without losing precision.
    public let id: String

    /// Product type. Drives both the icon shown on the dashboard tile
    /// and the sign convention for `balance` (see type-level doc).
    public let kind: AccountKind

    /// Customer-facing nickname, e.g. "Everyday Checking". Never the
    /// raw product code.
    public let displayName: String

    /// PAN-style masked number, e.g. "\u2022\u2022\u2022\u20224281". Always already masked at
    /// the boundary \u2014 this type never holds the full account number.
    public let maskedNumber: String

    /// See type-level doc for the sign convention.
    public let balance: Decimal

    public init(
        id: String,
        kind: AccountKind,
        displayName: String,
        maskedNumber: String,
        balance: Decimal
    ) {
        self.id           = id
        self.kind         = kind
        self.displayName  = displayName
        self.maskedNumber = maskedNumber
        self.balance      = balance
    }
}

/// The product type backing an `Account`.
///
/// Stored as its raw string when encoded so a future JSON wire format
/// (or analytics breadcrumb) is human-readable \u2014 do NOT change the
/// raw values, they're part of the persisted/serialised shape.
public enum AccountKind: String, Equatable, Hashable, Codable, CaseIterable {
    case checking
    case savings
    case credit
}
