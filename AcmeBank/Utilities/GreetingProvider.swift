import Foundation

/// Pure greeting computation used by the Home dashboard header.
///
/// The dashboard mockup shows a two-line salutation:
///
/// ```
/// Good morning,
/// Demo
/// ```
///
/// `GreetingProvider.greeting(for:firstName:)` produces the single
/// string that backs the WHOLE salutation — the View is responsible
/// for breaking it across two lines if it chooses to. Keeping the
/// time-of-day logic out of the ViewModel makes it trivially
/// boundary-testable on a deterministic injected `Date`.
///
/// ## Time-of-day windows
///
/// The windows are inclusive-lower / inclusive-upper on the hour
/// component of the device clock, in the current calendar:
///
/// | Window     | Hours (24h) | Copy              |
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
/// "5 a.m." means in absolute seconds. Anchoring on the user's
/// current `Calendar` keeps the greeting in step with what the device
/// clock face shows.
public enum GreetingProvider {

    /// Returns the full salutation string for the given moment and
    /// customer first name.
    ///
    /// - Parameters:
    ///   - date:      The moment whose hour-of-day drives the window
    ///                selection. Tests pin this to an exact `Date`;
    ///                production callers pass `Date()`.
    ///   - firstName: The customer's first name (e.g. `"Demo"`). Used
    ///                verbatim — capitalisation is the caller's
    ///                responsibility (the BFF already returns
    ///                canonical case).
    ///   - calendar:  Calendar used to extract the hour component.
    ///                Defaults to `.current` so the greeting follows
    ///                the user's locale / time zone. Tests inject a
    ///                fixed `Calendar` (typically `.gregorian` in UTC)
    ///                so a literal `Date` maps to a known hour.
    /// - Returns: e.g. `"Good morning, Demo"`.
    public static func greeting(
        for date: Date,
        firstName: String,
        calendar: Calendar = .current
    ) -> String {
        let hour = calendar.component(.hour, from: date)
        let prefix: String

        switch hour {
        case 5...11:
            prefix = "Good morning"
        case 12...16:
            prefix = "Good afternoon"
        default:
            // 17...23 and 0...4 — evening wraps past midnight so a
            // 3 a.m. user is not jarringly greeted with "Good morning".
            prefix = "Good evening"
        }

        return "\(prefix), \(firstName)"
    }
}
