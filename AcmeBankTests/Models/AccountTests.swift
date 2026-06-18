import XCTest
@testable import AcmeBank

/// Value-semantics + (de)coding sanity for `Account` / `AccountKind`.
final class AccountTests: XCTestCase {

    // MARK: - Equality

    func test_account_equality_isStructural() {
        let a = Account(
            id:           "acct-1",
            kind:         .checking,
            displayName:  "Everyday Checking",
            maskedNumber: "\u{2022}\u{2022}\u{2022}\u{2022}1234",
            balance:      Decimal(string: "100.00")!
        )
        let b = Account(
            id:           "acct-1",
            kind:         .checking,
            displayName:  "Everyday Checking",
            maskedNumber: "\u{2022}\u{2022}\u{2022}\u{2022}1234",
            balance:      Decimal(string: "100.00")!
        )
        XCTAssertEqual(a, b)
    }

    func test_account_equality_differsOnEveryField() {
        let base = Account(
            id:           "acct-1",
            kind:         .checking,
            displayName:  "Everyday Checking",
            maskedNumber: "\u{2022}\u{2022}\u{2022}\u{2022}1234",
            balance:      Decimal(string: "100.00")!
        )

        XCTAssertNotEqual(base, Account(id: "acct-2",
                                        kind: base.kind,
                                        displayName: base.displayName,
                                        maskedNumber: base.maskedNumber,
                                        balance: base.balance))
        XCTAssertNotEqual(base, Account(id: base.id,
                                        kind: .savings,
                                        displayName: base.displayName,
                                        maskedNumber: base.maskedNumber,
                                        balance: base.balance))
        XCTAssertNotEqual(base, Account(id: base.id,
                                        kind: base.kind,
                                        displayName: "Other",
                                        maskedNumber: base.maskedNumber,
                                        balance: base.balance))
        XCTAssertNotEqual(base, Account(id: base.id,
                                        kind: base.kind,
                                        displayName: base.displayName,
                                        maskedNumber: "\u{2022}\u{2022}\u{2022}\u{2022}9999",
                                        balance: base.balance))
        XCTAssertNotEqual(base, Account(id: base.id,
                                        kind: base.kind,
                                        displayName: base.displayName,
                                        maskedNumber: base.maskedNumber,
                                        balance: Decimal(string: "100.01")!))
    }

    func test_account_isHashable_sameValueHashesEqually() {
        let a = Account(id: "acct-1", kind: .savings, displayName: "S",
                        maskedNumber: "\u{2022}\u{2022}\u{2022}\u{2022}0001",
                        balance: Decimal(string: "1.23")!)
        let b = a
        XCTAssertEqual(a.hashValue, b.hashValue)
    }

    // MARK: - AccountKind round-trip

    func test_accountKind_rawValuesAreStableWireFormat() {
        // These raw values are part of the persisted shape \u2014 changing
        // them silently breaks any prior JSON snapshot. Guard against
        // accidental rename.
        XCTAssertEqual(AccountKind.checking.rawValue,   "checking")
        XCTAssertEqual(AccountKind.savings.rawValue,    "savings")
        XCTAssertEqual(AccountKind.credit.rawValue,     "credit")
        XCTAssertEqual(AccountKind.investment.rawValue, "investment")
    }

    func test_accountKind_codable_roundTripsAllCases() throws {
        for kind in AccountKind.allCases {
            let data    = try JSONEncoder().encode(kind)
            let decoded = try JSONDecoder().decode(AccountKind.self, from: data)
            XCTAssertEqual(decoded, kind, "Failed round-trip for \\(kind)")
        }
    }

    // MARK: - Account Codable

    func test_account_codable_roundTrip_preservesAllFields() throws {
        let original = Account(
            id:           "acct-credit-001",
            kind:         .credit,
            displayName:  "Acme Rewards Visa",
            maskedNumber: "\u{2022}\u{2022}\u{2022}\u{2022}9902",
            balance:      Decimal(string: "-842.16")!
        )

        let data    = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(Account.self, from: data)

        XCTAssertEqual(decoded, original)
    }

    // MARK: - availableBalance / currencyCode defaults

    func test_account_defaults_availableBalanceEqualsBalance_currencyUSD() {
        let a = Account(
            id:           "acct-1",
            kind:         .checking,
            displayName:  "Everyday",
            maskedNumber: "1234",
            balance:      Decimal(string: "100.00")!
        )
        XCTAssertEqual(a.availableBalance, Decimal(string: "100.00")!)
        XCTAssertEqual(a.currencyCode, "USD")
    }

    func test_account_explicit_availableBalanceAndCurrency_areHeld() {
        let credit = Account(
            id:               "acct-6",
            kind:             .credit,
            displayName:      "Cashback Mastercard",
            maskedNumber:     "4490",
            balance:          Decimal(string: "-243.10")!,
            availableBalance: Decimal(string: "4756.90")!,
            currencyCode:     "CAD"
        )
        XCTAssertEqual(credit.availableBalance, Decimal(string: "4756.90")!)
        XCTAssertEqual(credit.currencyCode, "CAD")
        // Equality is structural across the new fields too.
        XCTAssertNotEqual(
            credit,
            Account(id: credit.id, kind: credit.kind, displayName: credit.displayName,
                    maskedNumber: credit.maskedNumber, balance: credit.balance,
                    availableBalance: Decimal(string: "0.00")!, currencyCode: "CAD")
        )
    }
}
