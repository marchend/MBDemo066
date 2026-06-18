import Foundation

/// Shared USD currency formatter for the dashboard (and anywhere else
/// that needs to render an `Account.balance` or a `Transaction.amount`).
///
/// ## Why a dedicated type instead of an extension on `Decimal`
/// `NumberFormatter` is comparatively expensive to construct \u2014 it
/// resolves locale data on init. We hold a single shared instance
/// behind this facade so the dashboard rendering 5+ amounts per frame
/// doesn't re-spin a formatter each time.
///
/// ## Locale
/// Hard-pinned to `en_US` with currency code `USD`. The product is
/// US-only for this release; once we localise we'll route through the
/// user's locale here.
///
/// ## Thread-safety
/// `NumberFormatter` is an Objective-C class that mutates internal
/// state during `string(from:)` (formatting buffers, locale caches)
/// and is documented by Apple as **not thread-safe**. We hold a single
/// instance for construction-cost reasons, so every call to the
/// underlying formatter is serialised through `lock` below. Callers
/// can invoke `CurrencyFormatter.string(from:)` from any thread or
/// queue safely.
public enum CurrencyFormatter {

    /// Underlying `NumberFormatter`. `private` so callers can't mutate
    /// shared state \u2014 every call routes through `string(from:)`.
    private static let shared: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle             = .currency
        f.currencyCode            = "USD"
        f.locale                  = Locale(identifier: "en_US")
        f.minimumFractionDigits   = 2
        f.maximumFractionDigits   = 2
        // Render negatives with a leading minus (e.g. "-$842.16") rather
        // than parens, matching the dashboard mockup's credit-card row.
        //
        // Hard-coded to "-$" instead of derived from `f.currencySymbol`:
        // some locale/SDK combinations resolve the en_US currency symbol
        // to "US$" rather than "$", which would render "-US$842.16" and
        // break the dashboard snapshot. The whole formatter is already
        // pinned to USD/en_US, so the literal is safe and intent-revealing.
        f.negativePrefix          = "-$"
        f.negativeSuffix          = ""
        return f
    }()

    /// Serialises access to `shared`. See the type-level "Thread-safety"
    /// note. `NSLock` is sufficient here: the critical section is a
    /// single `string(from:)` call (microseconds), there is no
    /// reentrancy, and we want a synchronous API so the call sites in
    /// SwiftUI views don't need to be `async`.
    private static let lock = NSLock()

    /// Renders a `Decimal` as a USD currency string.
    ///
    /// Safe to call from any thread \u2014 access to the shared
    /// `NumberFormatter` is serialised internally.
    ///
    /// - Returns: e.g. `"$4,287.43"`, `"$0.00"`, `"-$842.16"`. Returns
    ///   `"$0.00"` as a defensive fallback in the (practically
    ///   unreachable) case where `NumberFormatter` rejects the input;
    ///   callers never get `nil` and never need to write fallback UI.
    public static func string(from amount: Decimal) -> String {
        // `NumberFormatter` takes `NSNumber`, not `Decimal` directly.
        let ns = NSDecimalNumber(decimal: amount)
        lock.lock()
        defer { lock.unlock() }
        return shared.string(from: ns) ?? "$0.00"
    }
}
