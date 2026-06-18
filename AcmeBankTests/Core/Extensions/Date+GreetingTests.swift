import XCTest
@testable import AcmeBank

/// Boundary coverage for the three greeting windows on the
/// `Date.greeting(firstName:calendar:)` extension.
///
/// Every test builds its `Date` against a UTC Gregorian calendar so
/// the hour component is exactly the literal we pass in — otherwise
/// the CI machine's local time zone could shift our 05:00 boundary
/// into a different window and produce a flaky pass.
final class DateGreetingTests: XCTestCase {

    // MARK: - Calendar / Date helpers

    /// A `Calendar` whose hour component matches the literal hour we
    /// build the `Date` from. Pinning the time zone to UTC avoids
    /// daylight-saving and CI-host-timezone flakes.
    private let utcCalendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(secondsFromGMT: 0)!
        return c
    }()

    /// Builds a `Date` at the literal `(hour, minute)` in UTC on a
    /// fixed reference day.
    private func date(hour: Int, minute: Int = 0) -> Date {
        let components = DateComponents(
            calendar: utcCalendar,
            timeZone: TimeZone(secondsFromGMT: 0),
            year:     2025,
            month:    6,
            day:      1,
            hour:     hour,
            minute:   minute
        )
        return components.date!
    }

    private func greet(hour: Int, minute: Int = 0, firstName: String = "Demo") -> String {
        date(hour: hour, minute: minute)
            .greeting(firstName: firstName, calendar: utcCalendar)
    }

    // MARK: - Morning window (05 — 11)

    func test_greeting_at_05_00_isMorning_lowerBoundary() {
        XCTAssertEqual(greet(hour: 5), "Good morning, Demo")
    }

    func test_greeting_at_08_30_isMorning_midWindow() {
        XCTAssertEqual(greet(hour: 8, minute: 30), "Good morning, Demo")
    }

    func test_greeting_at_11_59_isMorning_upperBoundary() {
        XCTAssertEqual(greet(hour: 11, minute: 59), "Good morning, Demo")
    }

    // MARK: - Afternoon window (12 — 16)

    func test_greeting_at_12_00_isAfternoon_lowerBoundary() {
        XCTAssertEqual(greet(hour: 12), "Good afternoon, Demo")
    }

    func test_greeting_at_14_15_isAfternoon_midWindow() {
        XCTAssertEqual(greet(hour: 14, minute: 15), "Good afternoon, Demo")
    }

    func test_greeting_at_16_59_isAfternoon_upperBoundary() {
        XCTAssertEqual(greet(hour: 16, minute: 59), "Good afternoon, Demo")
    }

    // MARK: - Evening window (17 — 04, wrapping past midnight)

    func test_greeting_at_17_00_isEvening_lowerBoundary() {
        XCTAssertEqual(greet(hour: 17), "Good evening, Demo")
    }

    func test_greeting_at_22_00_isEvening_midWindow() {
        XCTAssertEqual(greet(hour: 22), "Good evening, Demo")
    }

    func test_greeting_at_23_59_isEvening_justBeforeMidnight() {
        XCTAssertEqual(greet(hour: 23, minute: 59), "Good evening, Demo")
    }

    func test_greeting_at_00_00_isEvening_midnightWrap() {
        XCTAssertEqual(greet(hour: 0), "Good evening, Demo")
    }

    func test_greeting_at_04_59_isEvening_upperBoundaryBeforeMorning() {
        XCTAssertEqual(greet(hour: 4, minute: 59), "Good evening, Demo")
    }

    // MARK: - First name is rendered verbatim

    func test_greeting_usesProvidedFirstName_verbatim() {
        XCTAssertEqual(
            greet(hour: 9, firstName: "Alex"),
            "Good morning, Alex"
        )
    }

    func test_greeting_preservesCapitalisationOfFirstName() {
        // The BFF returns canonical case — the extension must NOT
        // re-capitalise (a user named "deMarco" should stay "deMarco").
        XCTAssertEqual(
            greet(hour: 13, firstName: "deMarco"),
            "Good afternoon, deMarco"
        )
    }

    // MARK: - `greetingPrefix` standalone

    func test_greetingPrefix_returnsPrefixOnly_withoutComma() {
        XCTAssertEqual(
            date(hour: 9).greetingPrefix(calendar: utcCalendar),
            "Good morning"
        )
        XCTAssertEqual(
            date(hour: 13).greetingPrefix(calendar: utcCalendar),
            "Good afternoon"
        )
        XCTAssertEqual(
            date(hour: 20).greetingPrefix(calendar: utcCalendar),
            "Good evening"
        )
    }
}
