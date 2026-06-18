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
/// resolver. PR 4 replaces the inline `_QuickActionPlaceholderView`
/// here with a real `PlaceholderDestinationView` shipped from its own
/// file; until then, the inline view keeps the screen self-contained
/// and compiling.
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

                        // ── Account carousel ───────────────────────
                        AccountCardCarousel(accounts: viewModel.accounts)

                        // ── Inline error banner ────────────────────
                        // `InlineErrorBannerView` already renders
                        // nothing when `message` is nil — pass the
                        // optional through directly to match the
                        // call-site pattern established by
                        // `LoginView`.
                        InlineErrorBannerView(message: viewModel.errorMessage)
                            .padding(.horizontal, 20)

                        // ── Quick actions ──────────────────────────
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
            // PR 4 swaps `_QuickActionPlaceholderView` for the real
            // `PlaceholderDestinationView` — the row itself does not
            // need to change.
            .navigationDestination(for: QuickAction.DestinationTag.self) { tag in
                _QuickActionPlaceholderView(tag: tag)
            }
            .task {
                await viewModel.load()
            }
        }
    }
}

// MARK: - Placeholder destination (replaced in PR 4)

/// Minimal stand-in for the real placeholder destination that PR 4
/// ships. Kept fileprivate (and underscore-prefixed) so a future
/// agent / reviewer doesn't mistake it for a stable API: PR 4 will
/// delete this view and register the real `PlaceholderDestinationView`
/// in the `.navigationDestination(for:)` resolver above.
private struct _QuickActionPlaceholderView: View {
    let tag: QuickAction.DestinationTag

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "hammer")
                .font(.system(size: 48))
                .foregroundStyle(Color.acmeNavy)

            Text(tag.rawValue.capitalized)
                .font(.title2)
                .fontWeight(.semibold)

            Text("Coming soon.")
                .font(.body)
                .foregroundStyle(Color.secondary)
        }
        .padding()
        .navigationTitle(tag.rawValue.capitalized)
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier("quickAction.placeholder.\(tag.rawValue)")
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
