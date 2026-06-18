import SwiftUI

/// Top-level Home dashboard screen (redesigned).
///
/// Renders the live BFF `GET /v1/home` payload top-to-bottom:
/// - Brand bar (hexagon "A" logo + "Acme Bank" wordmark)
/// - Two-line greeting ("Welcome back," / customer first name)
/// - Signed-in card (initials avatar, full name, phone, Okta trust row)
/// - Accounts section (one row per account)
/// - Recent Transactions section (one row per transaction)
/// - A centred Log out control
///
/// ## ViewModel ownership: `@StateObject`, not `@ObservedObject`
/// The ViewModel is constructed inside this view's `init` and stored
/// as a `@StateObject`, so SwiftUI owns its lifetime for the duration
/// the view is on screen. The composition root passes the
/// *dependencies* (`HomeRepositoryProtocol` + `SignedInUser` +
/// `onSignOut`) rather than a pre-built ViewModel; `view(for:)` is
/// re-evaluated on every `AppCoordinator` publish, so `@StateObject`'s
/// once-per-identity init is what keeps a re-render from discarding
/// already-loaded data and re-firing `load()`.
struct HomeDashboardView: View {

    @StateObject private var viewModel: HomeDashboardViewModel

    /// Invoked when the user taps Log out, or when the session expires
    /// (BFF 401). Routes back to the login screen via the composition
    /// root's `AppCoordinator.signOut()`.
    private let onSignOut: () -> Void

    /// Dependency-injecting init used by the composition root
    /// (`RootCoordinator.view(for:)`). The ViewModel is built lazily
    /// inside the `@StateObject` autoclosure so SwiftUI — not the
    /// caller — controls its lifetime.
    init(
        repository: HomeRepositoryProtocol,
        user: SignedInUser,
        onSignOut: @escaping () -> Void
    ) {
        _viewModel = StateObject(
            wrappedValue: HomeDashboardViewModel(
                repository: repository,
                user:       user
            )
        )
        self.onSignOut = onSignOut
    }

    /// Test / preview init that injects an already-built ViewModel.
    init(viewModel: HomeDashboardViewModel, onSignOut: @escaping () -> Void = {}) {
        _viewModel = StateObject(wrappedValue: viewModel)
        self.onSignOut = onSignOut
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {

                brandBar

                greetingHeader

                signedInCard

                accountsSection

                transactionsSection

                // Inline error + Retry for a non-auth load failure.
                if let message = viewModel.errorMessage {
                    errorBanner(message)
                }

                logOutButton
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 28)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
        .overlay {
            if viewModel.isLoading {
                ProgressView()
                    .progressViewStyle(.circular)
                    .scaleEffect(1.2)
                    .accessibilityIdentifier("dashboard.loadingSpinner")
            }
        }
        // A rejected token (401) can't be retried in place — route the
        // user back to login.
        .onChange(of: viewModel.sessionExpired) { _, expired in
            if expired { onSignOut() }
        }
        .task {
            await viewModel.load()
        }
    }

    // MARK: - Brand bar

    private var brandBar: some View {
        HStack(spacing: 10) {
            HexagonLogo()
                .frame(width: 34, height: 38)
                .accessibilityHidden(true)

            Text("Acme Bank")
                .font(.title3)
                .fontWeight(.bold)
                .foregroundStyle(Color.acmeNavy)

            Spacer(minLength: 0)
        }
        .padding(.vertical, 8)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Acme Bank")
    }

    // MARK: - Greeting

    private var greetingHeader: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("Welcome back,")
                .font(.subheadline)
                .foregroundStyle(Color.secondary)
            Text(viewModel.greetingFirstName)
                .font(.largeTitle)
                .fontWeight(.bold)
                .foregroundStyle(Color.primary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("dashboard.greeting")
    }

    // MARK: - Signed-in card

    @ViewBuilder
    private var signedInCard: some View {
        let customer = viewModel.customer
        VStack(alignment: .leading, spacing: 14) {
            Text("SIGNED IN")
                .font(.caption2)
                .fontWeight(.semibold)
                .tracking(1.2)
                .foregroundStyle(Color.white.opacity(0.6))

            HStack(spacing: 14) {
                ZStack {
                    Circle().fill(Color.white.opacity(0.15))
                    Text(customer?.initials ?? "")
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundStyle(Color.white)
                }
                .frame(width: 48, height: 48)

                VStack(alignment: .leading, spacing: 3) {
                    Text(customer?.fullName ?? " ")
                        .font(.headline)
                        .foregroundStyle(Color.white)
                    Text(customer?.phoneNumber ?? " ")
                        .font(.subheadline)
                        .foregroundStyle(Color.white.opacity(0.75))
                }

                Spacer(minLength: 0)
            }

            HStack(spacing: 8) {
                Image(systemName: "checkmark.shield.fill")
                    .foregroundStyle(Color.green)
                    .accessibilityHidden(true)
                Text("Authenticated via Okta \u{00B7} Customer \(customer?.id ?? "")")
                    .font(.caption)
                    .foregroundStyle(Color.white.opacity(0.85))
                Spacer(minLength: 0)
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.white.opacity(0.08))
            )
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.acmeNavy)
        )
        .accessibilityIdentifier("dashboard.signedInCard")
    }

    // MARK: - Accounts

    private var accountsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader("Accounts")

            VStack(spacing: 0) {
                ForEach(Array(viewModel.accounts.enumerated()), id: \.element.id) { index, account in
                    AccountRow(account: account)
                    if index < viewModel.accounts.count - 1 {
                        Divider().padding(.leading, 60)
                    }
                }
            }
            .cardBackground()
        }
    }

    // MARK: - Recent transactions

    private var transactionsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader("Recent Transactions")

            VStack(spacing: 0) {
                if viewModel.recentTransactions.isEmpty {
                    Text("No recent transactions.")
                        .font(.subheadline)
                        .foregroundStyle(Color.secondary)
                        .padding(16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    ForEach(Array(viewModel.recentTransactions.enumerated()), id: \.element.id) { index, txn in
                        TransactionRow(transaction: txn)
                        if index < viewModel.recentTransactions.count - 1 {
                            Divider().padding(.leading, 60)
                        }
                    }
                }
            }
            .cardBackground()
        }
    }

    // MARK: - Log out

    private var logOutButton: some View {
        Button(action: onSignOut) {
            VStack(spacing: 4) {
                Image(systemName: "rectangle.portrait.and.arrow.right")
                    .font(.system(size: 22, weight: .regular))
                Text("Log out")
                    .font(.subheadline)
            }
            .foregroundStyle(Color.secondary)
            .frame(maxWidth: .infinity)
            .padding(.top, 8)
        }
        .accessibilityIdentifier("dashboard.logOut")
        .accessibilityLabel("Log out")
    }

    // MARK: - Helpers

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.headline)
            .fontWeight(.bold)
            .foregroundStyle(Color.primary)
    }

    private func errorBanner(_ message: String) -> some View {
        VStack(spacing: 10) {
            Text(message)
                .font(.subheadline)
                .foregroundStyle(Color.red)
                .multilineTextAlignment(.center)
            Button("Retry") {
                Task { await viewModel.load() }
            }
            .buttonStyle(.bordered)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
        )
        .accessibilityIdentifier("dashboard.errorBanner")
    }
}

// MARK: - Hexagon logo

/// The brand bar's hexagonal "A" mark in Acme navy.
private struct HexagonLogo: View {
    var body: some View {
        ZStack {
            Hexagon()
                .fill(Color.acmeNavy)
            Text("A")
                .font(.system(size: 18, weight: .heavy, design: .rounded))
                .foregroundStyle(Color.white)
        }
    }
}

/// A flat-top hexagon path, scaled to its bounding rect.
private struct Hexagon: Shape {
    func path(in rect: CGRect) -> Path {
        let w = rect.width
        let h = rect.height
        var p = Path()
        p.move(to:    CGPoint(x: w * 0.50, y: 0))
        p.addLine(to: CGPoint(x: w,        y: h * 0.25))
        p.addLine(to: CGPoint(x: w,        y: h * 0.75))
        p.addLine(to: CGPoint(x: w * 0.50, y: h))
        p.addLine(to: CGPoint(x: 0,        y: h * 0.75))
        p.addLine(to: CGPoint(x: 0,        y: h * 0.25))
        p.closeSubpath()
        return p
    }
}

// MARK: - Account row

/// One account row in the Accounts card.
private struct AccountRow: View {
    let account: Account

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.acmeNavy)
                Image(systemName: "creditcard.fill")
                    .foregroundStyle(Color.white)
                    .font(.system(size: 18))
            }
            .frame(width: 44, height: 44)
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 3) {
                Text(account.displayName)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(Color.primary)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(Color.secondary)
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 3) {
                Text(balanceText)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(account.balance < 0 ? Color.red : Color.primary)
                Text(secondaryText)
                    .font(.caption)
                    .foregroundStyle(Color.secondary)
            }
        }
        .padding(16)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityIdentifier("accountRow.\(account.id)")
    }

    /// "{Type} · ····{last4}" — Type title-cased per the design,
    /// last4 pulled from the masked number.
    private var subtitle: String {
        "\(Self.typeLabel(for: account.kind)) \u{00B7} \u{00B7}\u{00B7}\u{00B7}\u{00B7}\(last4)"
    }

    /// Balance, currency-formatted on the row's own currency code.
    /// Negative balances render with a leading minus.
    private var balanceText: String {
        CurrencyFormatter.string(from: account.balance, currencyCode: account.currencyCode)
    }

    /// Gray subtext under the balance: the currency code for a normal
    /// (non-negative) balance, or "{available} available" for a
    /// negative (credit) balance.
    private var secondaryText: String {
        if account.balance < 0 {
            let available = CurrencyFormatter.string(
                from: account.availableBalance,
                currencyCode: account.currencyCode
            )
            return "\(available) available"
        }
        return account.currencyCode
    }

    private var last4: String {
        let digits = account.maskedNumber.filter(\.isNumber)
        return String(digits.suffix(4))
    }

    private var accessibilityLabel: String {
        "\(account.displayName), \(Self.typeLabel(for: account.kind)), balance \(balanceText)"
    }

    /// Title-cased product label per the design spec.
    static func typeLabel(for kind: AccountKind) -> String {
        switch kind {
        case .checking:   return "Chequing"
        case .savings:    return "Savings"
        case .credit:     return "Credit Card"
        case .investment: return "Investment"
        }
    }
}

// MARK: - Transaction row

/// One transaction row in the Recent Transactions card.
private struct TransactionRow: View {
    let transaction: Transaction

    /// `yyyy-MM-dd` (UTC) parser for the date-only wire value. Held
    /// statically so the row doesn't re-spin a formatter per render.
    private static let inputFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale     = Locale(identifier: "en_US_POSIX")
        f.timeZone   = TimeZone(identifier: "UTC")
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    /// "MMM d, yyyy" display formatter (e.g. "May 20, 2024").
    private static let displayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale     = Locale(identifier: "en_US")
        f.timeZone   = TimeZone(identifier: "UTC")
        f.dateFormat = "MMM d, yyyy"
        return f
    }()

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle().fill(Color(.systemGray5))
                Text(initial)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(Color.primary)
            }
            .frame(width: 44, height: 44)
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 3) {
                Text(transaction.merchantName)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(Color.primary)
                Text(formattedDate)
                    .font(.caption)
                    .foregroundStyle(Color.secondary)
            }

            Spacer(minLength: 8)

            Text(amountText)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(transaction.amount < 0 ? Color.primary : Color.green)
        }
        .padding(16)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(transaction.merchantName), \(formattedDate), \(amountText)")
        .accessibilityIdentifier("transactionRow.\(transaction.id)")
    }

    private var initial: String {
        transaction.merchantName.first.map { String($0).uppercased() } ?? "?"
    }

    private var amountText: String {
        CurrencyFormatter.string(from: transaction.amount, currencyCode: transaction.currencyCode)
    }

    /// Renders the `"YYYY-MM-DD"` string as "MMM d, yyyy". Falls back
    /// to the raw string if it doesn't parse (best-effort).
    private var formattedDate: String {
        guard let date = Self.inputFormatter.date(from: transaction.postedDate) else {
            return transaction.postedDate
        }
        return Self.displayFormatter.string(from: date)
    }
}

// MARK: - Card background

private extension View {
    /// White rounded-card chrome shared by the Accounts and Recent
    /// Transactions cards.
    func cardBackground() -> some View {
        self
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(.systemBackground))
            )
    }
}

// MARK: - Preview

#Preview("Loaded") {
    let vm = HomeDashboardViewModel(
        repository: StubAccountsRepository(),
        user: SignedInUser(
            firstName: "Bankuser",
            lastName:  "One",
            email:     "bankuser.one@example.com"
        )
    )
    return HomeDashboardView(viewModel: vm, onSignOut: {})
        .task { await vm.load() }
}
