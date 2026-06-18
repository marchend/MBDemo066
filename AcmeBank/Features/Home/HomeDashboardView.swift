import SwiftUI

/// Top-level Home dashboard screen.
///
/// Composition:
/// - `DashboardNavBar`         — logo + wordmark + bell with red badge
/// - `GreetingHeader`          — "Good morning, Demo"
/// - `AccountCardCarousel`     — horizontal cards over `vm.accounts`
/// - `QuickActionsRow`         — Transfer / Pay Bills / Deposit / More
/// - Loading spinner overlay when `vm.isLoading`
/// - Inline error banner       — `vm.errorMessage`
///
/// The view binds to `HomeDashboardViewModel` (PR 2) and kicks the
/// first load from `.task { await vm.load() }`. SwiftUI guarantees
/// `.task` runs once when the view first appears and is cancelled on
/// disappear, which is exactly the lifecycle the ViewModel's
/// "cancel any in-flight load" contract is designed around.
///
/// ## Navigation
/// `HomeDashboardView` owns the `NavigationStack` and registers a
/// single `.navigationDestination(for: QuickAction.DestinationTag.self)`
/// resolver. The resolver hands every tag (other than `.more`, which
/// `QuickActionsRow` renders as an inert button so no value is ever
/// pushed) to `PlaceholderDestinationView` \u2014 the dashboard mockup
/// reuses one "Coming soon" screen for Transfer / Pay Bills / Deposit.
struct HomeDashboardView: View {

    @ObservedObject var viewModel: HomeDashboardViewModel

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                DashboardNavBar()

                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {

                        GreetingHeader(
                            salutation: viewModel.greetingSalutation,
                            firstName:  viewModel.greetingFirstName
                        )

                        // ── Account carousel ────────────────────────
                        AccountCardCarousel(accounts: viewModel.accounts)

                        // ── Inline error banner ─────────────────────
                        // `InlineErrorBannerView` already renders
                        // nothing when `message` is nil — pass the
                        // optional through directly to match the
                        // call-site pattern established by
                        // `LoginView`.
                        InlineErrorBannerView(message: viewModel.errorMessage)
                            .padding(.horizontal, 20)

                        // ── Quick actions ───────────────────────────
                        QuickActionsRow()

                        Spacer(minLength: 24)
                    }
                    .padding(.top, 8)
                }
            }
            .background(Color(.systemGroupedBackground).ignoresSafeArea())
            // Centred spinner while the first (or a retry) load is in
            // flight. Overlay rather than replacing the layout so the
            // last-known-good carousel stays visible behind the
            // spinner on a retry.
            .overlay {
                if viewModel.isLoading {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .scaleEffect(1.2)
                        .accessibilityIdentifier("dashboard.loadingSpinner")
                }
            }
            // Single destination resolver for every QuickAction push.
            // `.more` is rendered as an inert Button by
            // `QuickActionsRow` (no NavigationLink value emitted), so
            // this resolver only ever fires for Transfer / Pay Bills
            // / Deposit \u2014 each maps to the shared
            // `PlaceholderDestinationView` until the real feature
            // screens ship.
            .navigationDestination(for: QuickAction.DestinationTag.self) { tag in
                PlaceholderDestinationView(
                    title: Self.placeholderTitle(for: tag),
                    accessibilityTag: tag.rawValue
                )
            }
            .task {
                await viewModel.load()
            }
        }
    }

    /// Human-readable title shown on the placeholder for a given
    /// quick-action tag. Kept alongside the resolver so the
    /// raw-enum-case to "Pay Bills" / "Deposit" / "Transfer" mapping
    /// lives in one place. `.more` is included for completeness even
    /// though `QuickActionsRow` never pushes it \u2014 a future PR that
    /// wires More to a real destination will replace the case here.
    static func placeholderTitle(for tag: QuickAction.DestinationTag) -> String {
        switch tag {
        case .transfer: return "Transfer"
        case .payBills: return "Pay Bills"
        case .deposit:  return "Deposit"
        case .more:     return "More"
        }
    }
}

// MARK: - Preview

#Preview("Loaded") {
    let vm = HomeDashboardViewModel(
        repository: StubAccountsRepository(),
        user: SignedInUser(
            firstName: "Demo",
            lastName:  "Person",
            email:     "demo.person@example.com"
        )
    )
    return HomeDashboardView(viewModel: vm)
        .task { await vm.load() }
}
