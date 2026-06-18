import SwiftUI

/// Horizontally-scrolling row of `AccountCard`s.
///
/// Renders `accounts` in the exact order the repository returned them
/// — the dashboard mockup pins fixture order, so we deliberately do
/// not re-sort here. (See `StubAccountsRepository.fixtures` for the
/// canonical order.)
struct AccountCardCarousel: View {

    let accounts: [Account]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(accounts) { account in
                    AccountCard(account: account)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 4)
        }
        .accessibilityIdentifier("dashboard.accountCarousel")
    }
}

#Preview {
    AccountCardCarousel(accounts: StubAccountsRepository.fixtures)
        .background(Color(.systemGroupedBackground))
}
