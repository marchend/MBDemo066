import SwiftUI

/// Row of four quick-action buttons under the account carousel.
///
/// Reads the canonical `QuickAction.dashboardDefaults` so the order /
/// titles / SF Symbols match the contract pinned by `QuickActionTests`.
///
/// ## Navigation model
/// Three of the four actions push the dashboard's placeholder
/// destination; the fourth ("More") is a no-op per the mockup. We
/// model this by emitting `NavigationLink(value:)` for the three
/// pushable actions and a plain `Button { }` for "More". The outer
/// `HomeDashboardView` registers a single
/// `.navigationDestination(for: QuickAction.DestinationTag.self)` that
/// resolves each tag to the actual destination view — PR 4 swaps the
/// inline placeholder for the real `PlaceholderDestinationView`
/// without touching the row.
struct QuickActionsRow: View {

    /// Actions to render. Defaults to the canonical four; overridable
    /// for previews / tests.
    var actions: [QuickAction] = QuickAction.dashboardDefaults

    var body: some View {
        HStack(spacing: 12) {
            ForEach(actions) { action in
                quickActionButton(for: action)
            }
        }
        .padding(.horizontal, 20)
        .accessibilityIdentifier("dashboard.quickActions")
    }

    @ViewBuilder
    private func quickActionButton(for action: QuickAction) -> some View {
        if action.destination == .more {
            // No-op per the mockup — render as a plain Button so the
            // tap surface and visual treatment match the other three,
            // but the tap action is empty.
            Button(action: {}) {
                quickActionLabel(for: action)
            }
            .accessibilityLabel(action.title)
            .accessibilityIdentifier("quickAction.\(action.destination.rawValue)")
        } else {
            // NavigationLink(value:) defers destination resolution to
            // the enclosing NavigationStack's `.navigationDestination`
            // — see HomeDashboardView for the resolver.
            NavigationLink(value: action.destination) {
                quickActionLabel(for: action)
            }
            .accessibilityLabel(action.title)
            .accessibilityIdentifier("quickAction.\(action.destination.rawValue)")
        }
    }

    private func quickActionLabel(for action: QuickAction) -> some View {
        VStack(spacing: 8) {
            Image(systemName: action.systemImage)
                .font(.system(size: 22, weight: .regular))
                .foregroundStyle(Color.acmeNavy)
                .frame(width: 48, height: 48)
                .background(
                    Circle()
                        .fill(Color.acmeNavy.opacity(0.08))
                )

            Text(action.title)
                .font(.caption)
                .foregroundStyle(Color.primary)
        }
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
    }
}

#Preview {
    NavigationStack {
        QuickActionsRow()
            .padding(.vertical)
    }
}
