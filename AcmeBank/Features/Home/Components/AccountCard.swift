import SwiftUI

/// A single account tile in the dashboard carousel.
///
/// Renders, from top to bottom:
/// - Kind icon (SF Symbol picked by `Account.kind`)
/// - Display name (e.g. "Everyday Checking")
/// - Masked number (the model's pre-masked `••••4281`)
/// - Balance, formatted via `CurrencyFormatter`. Negative balances
///   render in red so the credit-card "you owe" row reads at a glance.
///
/// ## Why the formatter lives here, not in the model
/// `Account.balance` is `Decimal` so it round-trips the wire format
/// without binary-float drift. The dashboard is the first place a
/// human sees the number, so this is also the right place to render
/// it. `CurrencyFormatter` is the project's single shared en_US USD
/// formatter — using it from every balance call site keeps the
/// formatting locale-pinned and avoids the "this card shows
/// `4287.43`, that card shows `$4,287.43`" inconsistency.
struct AccountCard: View {

    let account: Account

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {

            // ── Kind icon ──────────────────────────────────────────
            Image(systemName: Self.symbol(for: account.kind))
                .font(.system(size: 22, weight: .regular))
                .foregroundStyle(Color.acmeNavy)
                .frame(width: 32, height: 32)
                .accessibilityHidden(true)

            Spacer(minLength: 0)

            // ── Display name ───────────────────────────────────────
            Text(account.displayName)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(Color.primary)
                .lineLimit(1)

            // ── Masked number ──────────────────────────────────────
            Text(account.maskedNumber)
                .font(.caption)
                .foregroundStyle(Color.secondary)

            // ── Balance ────────────────────────────────────────────
            Text(CurrencyFormatter.string(from: account.balance))
                .font(.title3)
                .fontWeight(.bold)
                .foregroundStyle(account.balance < 0 ? Color.red : Color.primary)
                .accessibilityIdentifier("accountCard.balance.\(account.id)")
        }
        .padding(16)
        .frame(width: 200, height: 160, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color(.systemGray4), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.04), radius: 4, x: 0, y: 2)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Self.accessibilityLabel(for: account))
        .accessibilityIdentifier("accountCard.\(account.id)")
    }

    // MARK: - Helpers

    /// SF Symbol picked per account kind. Static so the mapping is
    /// trivially audit-able and stays out of the view body.
    static func symbol(for kind: AccountKind) -> String {
        switch kind {
        case .checking: return "banknote"
        case .savings:  return "chart.line.uptrend.xyaxis"
        case .credit:   return "creditcard"
        }
    }

    /// Composed VoiceOver label for the card. Reads like a sentence:
    /// "Checking, ending 4281, balance $4,287.43".
    static func accessibilityLabel(for account: Account) -> String {
        let kindWord: String
        switch account.kind {
        case .checking: kindWord = "Checking"
        case .savings:  kindWord = "Savings"
        case .credit:   kindWord = "Credit"
        }
        // Pull the last 4 from the masked number (strip non-digits).
        let last4 = account.maskedNumber.filter(\.isNumber)
        let balance = CurrencyFormatter.string(from: account.balance)
        return "\(kindWord), ending \(last4), balance \(balance)"
    }
}

#Preview {
    HStack(spacing: 12) {
        AccountCard(account: StubAccountsRepository.fixtures[0])
        AccountCard(account: StubAccountsRepository.fixtures[2])
    }
    .padding()
    .background(Color(.systemGroupedBackground))
}
