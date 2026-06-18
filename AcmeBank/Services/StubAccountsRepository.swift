import Foundation

/// In-memory `AccountsRepository` returning the three fixture accounts
/// shown on the dashboard mockup. Used by SwiftUI previews and by any
/// build that doesn't yet have the real `AccountAPIRepository` wired.
///
/// Fixture order is intentionally `[checking, savings, credit]` \u2014 the
/// dashboard renders accounts in the order the repository returns
/// them, so reordering here visibly reorders the UI.
public struct StubAccountsRepository: AccountsRepository, HomeRepositoryProtocol {

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

    /// A realistic `/v1/home` fixture mirroring the BFF contract
    /// (the "Bankuser One" sample) so previews and tests of the
    /// redesigned dashboard render the full customer + accounts +
    /// transactions layout without a live backend.
    public static let homeFixture: HomeDashboard = HomeDashboard(
        customer: Customer(
            id:          "cust-1002",
            firstName:   "Bankuser",
            lastName:    "One",
            phoneNumber: "+1-647-555-0198"
        ),
        accounts: [
            Account(
                id:               "acct-4",
                kind:             .checking,
                displayName:      "Everyday Chequing",
                maskedNumber:     "3310",
                balance:          Decimal(string: "1542.88")!,
                availableBalance: Decimal(string: "1542.88")!,
                currencyCode:     "USD"
            ),
            Account(
                id:               "acct-5",
                kind:             .savings,
                displayName:      "Rainy Day Savings",
                maskedNumber:     "8821",
                balance:          Decimal(string: "18230.55")!,
                availableBalance: Decimal(string: "18230.55")!,
                currencyCode:     "USD"
            ),
            Account(
                id:               "acct-6",
                kind:             .credit,
                displayName:      "Cashback Mastercard",
                maskedNumber:     "4490",
                balance:          Decimal(string: "-243.10")!,
                availableBalance: Decimal(string: "4756.90")!,
                currencyCode:     "USD"
            ),
        ],
        recentTransactions: [
            Transaction(
                id:           "txn-4001",
                accountId:    "acct-4",
                postedDate:   "2024-05-20",
                merchantName: "Toronto Hydro",
                amount:       Decimal(string: "-148.22")!,
                currencyCode: "USD"
            ),
            Transaction(
                id:           "txn-4002",
                accountId:    "acct-4",
                postedDate:   "2024-05-18",
                merchantName: "Loblaws",
                amount:       Decimal(string: "-86.40")!,
                currencyCode: "USD"
            ),
            Transaction(
                id:           "txn-4003",
                accountId:    "acct-4",
                postedDate:   "2024-05-15",
                merchantName: "Payroll Deposit",
                amount:       Decimal(string: "2400.00")!,
                currencyCode: "USD"
            ),
        ]
    )

    public init() {}

    public func fetchAccounts() async throws -> [Account] {
        return Self.fixtures
    }

    public func fetchHome() async throws -> HomeDashboard {
        return Self.homeFixture
    }
}
