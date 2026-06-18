import XCTest
@testable import AcmeBank

/// Pins the `AccountCard` VoiceOver-label contract.
///
/// `AccountCard.accessibilityLabel(for:)` builds the spoken card
/// summary by stripping non-digits from `Account.maskedNumber` to
/// recover the trailing 4 digits. That filter works perfectly for
/// the BFF's current `"••••4281"` bullet-masked format, but would
/// silently produce a malformed VoiceOver string ("Checking,
/// ending , ..." or "...ending 42811...") if the server ever
/// returned a different masked-number shape.
///
/// These tests pin the contract: for every fixture account, the
/// `last4` substring of the accessibility label must be exactly four
/// digits. If a future change to `StubAccountsRepository.fixtures`
/// (or to the masked-number format produced by the real
/// `AccountAPIRepository`, once it lands) introduces a non-digit-rich
/// masked number, these tests will fire before VoiceOver users hit
/// the silent failure.
///
/// Co-located with `QuickActionTests` — both are small data-contract
/// pins on the Home-dashboard UI layer.
final class AccountCardTests: XCTestCase {

    // MARK: - last4 contract

    func test_accessibilityLabel_containsExactlyFourTrailingDigits_forEveryFixture() {
        for account in StubAccountsRepository.fixtures {
            let last4 = account.maskedNumber.filter(\.isNumber)
            XCTAssertEqual(
                last4.count,
                4,
                "Fixture \(account.id) maskedNumber \(account.maskedNumber) " +
                "yields \(last4.count) digits, expected exactly 4. " +
                "AccountCard.accessibilityLabel would render a malformed " +
                "VoiceOver string."
            )
        }
    }

    func test_accessibilityLabel_containsLast4_forEveryFixture() {
        // Belt-and-braces: assert the composed label actually carries
        // those four digits in the "ending <last4>" slot — a future
        // refactor that drops the `ending` clause would slip past
        // the digit-count test above.
        for account in StubAccountsRepository.fixtures {
            let label = AccountCard.accessibilityLabel(for: account)
            let last4 = account.maskedNumber.filter(\.isNumber)
            XCTAssertTrue(
                label.contains("ending \(last4)"),
                "Expected accessibility label to contain 'ending \(last4)' " +
                "for fixture \(account.id); got \"\(label)\""
            )
        }
    }

    // MARK: - Pinned fixture digits

    /// Pins the exact `last4` for each fixture so a silent change to
    /// `StubAccountsRepository` is loud here. Hard-coded rather than
    /// derived so a copy-paste mistake in the fixture itself shows
    /// up as a test failure rather than a tautology.
    func test_accessibilityLabel_pinsExpectedLast4_perFixture() {
        let expected: [String: String] = [
            "acct-checking-001": "4281",
            "acct-savings-001":  "7735",
            "acct-credit-001":   "9902",
        ]
        for account in StubAccountsRepository.fixtures {
            guard let want = expected[account.id] else {
                XCTFail("Unexpected fixture id \(account.id) — " +
                        "update the expected-last4 table in this test.")
                continue
            }
            let got = account.maskedNumber.filter(\.isNumber)
            XCTAssertEqual(
                got, want,
                "Fixture \(account.id) last4 drifted: expected \(want), got \(got)"
            )
        }
    }
}
