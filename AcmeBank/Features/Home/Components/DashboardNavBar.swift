import SwiftUI

/// Top nav bar for the Home dashboard.
///
/// Layout (left → right):
/// - Hexagonal "A" logo + "Acme Bank" wordmark
/// - `Spacer`
/// - Bell icon with a static red badge dot anchored top-trailing
///
/// The bell is intentionally a no-op tap target in this PR — the
/// notification surface ships in a later story. We still render the
/// red dot so the dashboard matches the mockup visually and so users
/// see a "you have unread notifications" affordance from day one.
///
/// ## Why the logo is rendered via `AcmeLogoView` (synthetic) not the asset
/// The plan declares an `AcmeLogo.imageset/` slot, but the imageset
/// ships without raster bits (it's seeded so future PRs can drop in a
/// designed asset without touching `project.yml`). To avoid showing a
/// missing-asset placeholder on day one we render the existing
/// `AcmeLogoView` (the same hexagonal "A" used on the login screen) at
/// a small size — this matches the mockup pixel-for-pixel and is the
/// "SF Symbol / synthetic fallback" path the plan explicitly permits.
struct DashboardNavBar: View {

    /// Tap handler for the bell. Defaults to a no-op so the standard
    /// usage `DashboardNavBar()` matches the mockup contract; tests /
    /// previews can inject their own closure.
    var onBellTap: () -> Void = {}

    var body: some View {
        HStack(spacing: 12) {

            // ── Logo + wordmark ────────────────────────────────────
            HStack(spacing: 8) {
                AcmeLogoView(size: 32)
                    .accessibilityHidden(true)  // wordmark already labels the brand

                Text("Acme Bank")
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundStyle(Color.acmeNavy)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Acme Bank")

            Spacer()

            // ── Bell + badge ───────────────────────────────────────
            Button(action: onBellTap) {
                Image(systemName: "bell")
                    .font(.system(size: 20, weight: .regular))
                    .foregroundStyle(Color.acmeNavy)
                    .frame(width: 32, height: 32)
                    .overlay(alignment: .topTrailing) {
                        // 8 pt red dot, anchored to the top-trailing
                        // corner of the bell glyph. Static — we don't
                        // model "unread count" yet.
                        Circle()
                            .fill(Color.red)
                            .frame(width: 8, height: 8)
                            .offset(x: -2, y: 2)
                            .accessibilityHidden(true)
                    }
            }
            .accessibilityLabel("Notifications, unread")
            .accessibilityIdentifier("dashboardNavBar.bell")
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }
}

#Preview {
    DashboardNavBar()
        .background(Color(.systemBackground))
}
