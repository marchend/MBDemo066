import Foundation

/// Time-of-day greeting logic for the Home dashboard header.
///
/// Lives on `Date` (as specified in `bootstrap.md` §2 and `AGENT.md`'s
/// Planned Architecture section) so future features can discover and
/// reuse it via the established `Core/Extensions/` namespace alongside
/// `Decimal+Currency`, `String+Initials`, etc.
///
/// The dashboard mockup shows a two-line salutation:
///
/// ```
/// Good morning,
/// Demo
/// ```
///
/// `Date.greeting(firstName:calendar:)` produces the single string
/// that backs the WHOLE salutation — the View is responsible for
/// breaking it across two lines if it chooses to. Keeping the
/// time-of-day logic out of the ViewModel makes it trivially
/// boundary-testable on a deterministic `Date`.
///
/// ## Time-of-day windows
///
/// The windows are inclusive on the hour component of the device
/// clock, in the supplied calendar:
///
/// | Window     | Hours (24h) | Prefix            |
/// |------------|-------------|-------------------|
/// | Morning    | 05 — 11     | "Good morning"    |
/// | Afternoon  | 12 — 16     | "Good afternoon"  |
/// | Evening    | 17 — 04     | "Good evening"    |
///
/// The "Evening" window deliberately wraps past midnight so that
/// 22:00, 00:00, and 04:00 all greet the user with "Good evening"
/// rather than the jarring "Good morning" the mockup never shows at
/// 3 a.m.
///
/// ## Why a `Calendar` rather than `Date.timeIntervalSinceReferenceDate`
///
/// The user-perceived "hour" is a *calendar* concept — daylight saving
/// changes, time zones, and non-Gregorian calendars all shift what
/// "5 a.m." means in absolute seconds. Anchoring on a `Calendar` keeps
/// the greeting in step with what the device clock face shows.
public extension Date {

    /// Time-of-day prefix only, e.g. `"Good morning"`.
    ///
    /// - Parameter calendar: Calendar used to extract the hour
    ///   component. Defaults to `.current` so the greeting follows
    ///   the user's locale / time zone. Tests inject a fixed
    ///   `Calendar` (typically `.gregorian` in UTC) so a literal
    ///   `Date` maps to a known hour.
    func greetingPrefix(calendar: Calendar = .current) -> String {
        let hour = calendar.component(.hour, from: self)
        switch hour {
        case 5...11:
            return "Good morning"
        case 12...16:
            return "Good afternoon"
        default:
            // 17...23 and 0...4 — evening wraps past midnight so a
            // 3 a.m. user is not jarringly greeted with "Good morning".
            return "Good evening"
        }
    }

    /// Returns the full salutation string for this moment and the
    /// supplied customer first name, e.g. `"Good morning, Demo"`.
    ///
    /// - Parameters:
    ///   - firstName: The customer's first name (e.g. `"Demo"`). Used
    ///     verbatim — capitalisation is the caller's responsibility
    ///     (the BFF already returns canonical case).
    ///   - calendar:  Calendar used to extract the hour component.
    ///     Defaults to `.current`; see `greetingPrefix(calendar:)`.
    func greeting(firstName: String, calendar: Calendar = .current) -> String {
        "\(greetingPrefix(calendar: calendar)), \(firstName)"
    }
}
