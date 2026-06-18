import XCTest
@testable import AcmeBank

/// Verifies the stub returns the fixture set the dashboard mockup
/// depends on. If the dashboard ever shows a different number of
/// tiles, or a wrong amount, the failure should surface HERE first
/// rather than as a UI regression downstream.
final class StubAccountsRepositoryTests: XCTestCase {

    // MARK: - Shape

    func test_fetchAccounts_returnsExactlyThreeFixtures() async throws {
        let repo     = StubAccountsRepository()
        let accounts = try await repo.fetchAccounts()
        XCTAssertEqual(accounts.count, 3)
    }

    func test_fetchAccounts_returnsCheckingSavingsCredit_inThatOrder() async throws {
        let repo     = StubAccountsRepository()
        let accounts = try await repo.fetchAccounts()

        XCTAssertEqual(accounts.map(\.kind), [.checking, .savings, .credit])
    }

    func test_fetchAccounts_idsAreUnique() async throws {
        let repo     = StubAccountsRepository()
        let accounts = try await repo.fetchAccounts()

        let uniqueIds = Set(accounts.map(\.id))
        XCTAssertEqual(uniqueIds.count, accounts.count)
    }

    // MARK: - Balance sign convention

    func test_checking_and_savings_haveNonNegativeBalances() async throws {
        let repo     = StubAccountsRepository()
        let accounts = try await repo.fetchAccounts()

        for account in accounts where account.kind == .checking || account.kind == .savings {
            XCTAssertGreaterThanOrEqual(
                account.balance, 0,
                "\(account.kind.rawValue) fixture should not be negative; got \(account.balance)"
            )
        }
    }

    func test_credit_balance_isNegative_matchingMockupOwedConvention() async throws {
        let repo     = StubAccountsRepository()
        let accounts = try await repo.fetchAccounts()

        let credit = try XCTUnwrap(accounts.first(where: { $0.kind == .credit }))
        XCTAssertLessThan(credit.balance, 0)
    }

    // MARK: - Fixture values pinned to the mockup

    func test_fetchAccounts_balances_matchTheDashboardMockup() async throws {
        let repo     = StubAccountsRepository()
        let accounts = try await repo.fetchAccounts()

        XCTAssertEqual(accounts[0].balance, Decimal(string: "4287.43")!)
        XCTAssertEqual(accounts[1].balance, Decimal(string: "12500.00")!)
        XCTAssertEqual(accounts[2].balance, Decimal(string: "-842.16")!)
    }

    func test_fetchAccounts_displayNamesAndMasks_areCustomerFacing() async throws {
        let repo     = StubAccountsRepository()
        let accounts = try await repo.fetchAccounts()

        for account in accounts {
            XCTAssertFalse(account.displayName.isEmpty,
                           "\(account.kind.rawValue) is missing a display name")
            // Mask must be present and short (suffix only) \u2014 NEVER the
            // full PAN.
            XCTAssertFalse(account.maskedNumber.isEmpty)
            XCTAssertLessThanOrEqual(account.maskedNumber.count, 8,
                                     "maskedNumber looks too long to be a mask: \(account.maskedNumber)")
        }
    }

    // MARK: - Static fixtures match instance output

    func test_staticFixtures_matchFetchAccountsOutput() async throws {
        let repo     = StubAccountsRepository()
        let accounts = try await repo.fetchAccounts()

        XCTAssertEqual(accounts, StubAccountsRepository.fixtures)
    }

    // MARK: - fetchHome() fixture

    func test_fetchHome_returnsBankuserOneCustomer() async throws {
        let home = try await StubAccountsRepository().fetchHome()
        XCTAssertEqual(home.customer.id, "cust-1002")
        XCTAssertEqual(home.customer.fullName, "Bankuser One")
        XCTAssertEqual(home.customer.initials, "BO")
        XCTAssertEqual(home.customer.phoneNumber, "+1-647-555-0198")
    }

    func test_fetchHome_includesAccountsAndTransactions() async throws {
        let home = try await StubAccountsRepository().fetchHome()
        XCTAssertFalse(home.accounts.isEmpty, "home fixture should carry accounts")
        XCTAssertFalse(home.recentTransactions.isEmpty, "home fixture should carry transactions")

        // The credit fixture carries a separate available balance and
        // a negative balance, which the dashboard renders specially.
        let credit = try XCTUnwrap(home.accounts.first(where: { $0.kind == .credit }))
        XCTAssertLessThan(credit.balance, 0)
        XCTAssertGreaterThan(credit.availableBalance, credit.balance)
        XCTAssertEqual(credit.currencyCode, "USD")
    }

    func test_fetchHome_matchesStaticHomeFixture() async throws {
        let home = try await StubAccountsRepository().fetchHome()
        XCTAssertEqual(home, StubAccountsRepository.homeFixture)
    }
}
