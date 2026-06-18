import XCTest
@testable import AcmeBank

/// Locks the on-screen format used across the dashboard. These exact
/// strings appear in the mockup \u2014 changing them is a UI change.
final class CurrencyFormatterTests: XCTestCase {

    // MARK: - Positive amounts

    func test_positiveBalance_rendersWithDollarSignAndTwoFractionDigits() {
        XCTAssertEqual(
            CurrencyFormatter.string(from: Decimal(string: "4287.43")!),
            "$4,287.43"
        )
    }

    func test_largePositiveBalance_includesThousandsGrouping() {
        XCTAssertEqual(
            CurrencyFormatter.string(from: Decimal(string: "12500.00")!),
            "$12,500.00"
        )
    }

    func test_veryLargeBalance_groupsMillions() {
        XCTAssertEqual(
            CurrencyFormatter.string(from: Decimal(string: "1234567.89")!),
            "$1,234,567.89"
        )
    }

    // MARK: - Zero

    func test_zeroBalance_rendersAsDollarZeroZeroZero() {
        XCTAssertEqual(
            CurrencyFormatter.string(from: Decimal(0)),
            "$0.00"
        )
    }

    // MARK: - Negative (credit card)

    func test_negativeBalance_rendersWithLeadingMinus_notParens() {
        // The dashboard mockup shows credit-card debt as "-$842.16",
        // NOT "($842.16)" \u2014 lock that contract here.
        XCTAssertEqual(
            CurrencyFormatter.string(from: Decimal(string: "-842.16")!),
            "-$842.16"
        )
    }

    func test_smallNegativeBalance_stillRoundsToTwoDigits() {
        XCTAssertEqual(
            CurrencyFormatter.string(from: Decimal(string: "-0.05")!),
            "-$0.05"
        )
    }

    // MARK: - Fraction padding

    func test_oneFractionDigit_isPaddedToTwo() {
        XCTAssertEqual(
            CurrencyFormatter.string(from: Decimal(string: "10.5")!),
            "$10.50"
        )
    }

    func test_threeFractionDigits_areRoundedToTwo() {
        // Banker's rounding behaviour isn't promised by the API \u2014 we
        // just lock that the output is exactly two fraction digits.
        let rendered = CurrencyFormatter.string(from: Decimal(string: "10.125")!)
        // Must be either $10.12 or $10.13 \u2014 never three fraction digits.
        XCTAssertTrue(
            rendered == "$10.12" || rendered == "$10.13",
            "Expected two-fraction-digit rounding, got \(rendered)"
        )
    }
}
