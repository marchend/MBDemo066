import SwiftUI

/// Generic "this feature isn't built yet" screen pushed onto the
/// Home dashboard's navigation stack when the user taps
/// Transfer / Pay Bills / Deposit.
///
/// ## Why a single shared placeholder?
/// The dashboard mockup wires three quick actions to dedicated
/// feature areas that ship in later stories (transfers, bill pay,
/// mobile deposit). Until those land we need *some* destination so
/// the navigation push actually presents a screen \u2014 a missing
/// destination would either crash (`navigationDestination` resolver
/// returns nothing) or silently no-op, both of which would mask the
/// "the dashboard is wired into the composition root" verification
/// this PR exists to deliver.
///
/// Keeping a single titled placeholder (rather than three separate
/// stub feature views) means a future PR replaces the
/// `.navigationDestination(for:)` resolver in `HomeDashboardView`
/// one branch at a time, and this file gets deleted when all three
/// real destinations are in place.
///
/// ## Accessibility identifier
/// Uses the same `quickAction.placeholder.<tag>` identifier scheme
/// the prior inline placeholder used, so `HomeDashboardUITests` can
/// assert "tapping Transfer pushes a placeholder" without depending
/// on which file owns the view.
struct PlaceholderDestinationView: View {

    /// Title rendered as both the large body label and the nav-bar
    /// title (inline display mode). Caller passes the human-readable
    /// label \u2014 "Transfer", "Pay Bills", "Deposit" \u2014 not a raw enum
    /// case, so the screen reads naturally if a user lands here.
    let title: String

    /// Accessibility identifier suffix. Defaults to a slugged form
    /// of `title` so the call site doesn't have to repeat itself,
    /// but `HomeDashboardView` passes the `QuickAction.DestinationTag`
    /// raw value to keep the identifier stable across copy changes.
    var accessibilityTag: String

    init(title: String, accessibilityTag: String? = nil) {
        self.title = title
        self.accessibilityTag = accessibilityTag
            ?? title.lowercased().replacingOccurrences(of: " ", with: "")
    }

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "hammer")
                .font(.system(size: 48))
                .foregroundStyle(Color.acmeNavy)
                .accessibilityHidden(true)

            Text(title)
                .font(.title2)
                .fontWeight(.semibold)

            Text("Coming soon.")
                .font(.body)
                .foregroundStyle(Color.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier("quickAction.placeholder.\(accessibilityTag)")
    }
}

#Preview {
    NavigationStack {
        PlaceholderDestinationView(title: "Transfer", accessibilityTag: "transfer")
    }
}
