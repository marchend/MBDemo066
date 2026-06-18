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
        f.negativePrefix          = "-\(f.currencySymbol ?? "$")"
        f.negativeSuffix          = ""
        return f
    }()

    /// Renders a `Decimal` as a USD currency string.
    ///
    /// - Returns: e.g. `"$4,287.43"`, `"$0.00"`, `"-$842.16"`. Returns
    ///   `"$0.00"` as a defensive fallback in the (practically
    ///   unreachable) case where `NumberFormatter` rejects the input;
    ///   callers never get `nil` and never need to write fallback UI.
    public static func string(from amount: Decimal) -> String {
        // `NumberFormatter` takes `NSNumber`, not `Decimal` directly.
        let ns = NSDecimalNumber(decimal: amount)
        return shared.string(from: ns) ?? "$0.00"
    }
}
