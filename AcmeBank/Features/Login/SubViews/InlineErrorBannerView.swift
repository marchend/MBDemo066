import SwiftUI

/// A reusable inline error strip.
/// Hidden when `message` is `nil`; visible (with correct copy) when set.
struct InlineErrorBannerView: View {
    let message: String?

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(Color.red)

            Text(message ?? "")
                .font(.subheadline)
                .foregroundStyle(Color.red)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)

            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.red.opacity(0.08))
        )
        .opacity(message == nil ? 0 : 1)
        .accessibilityIdentifier("inlineErrorBanner")
        .accessibilityHidden(message == nil)
    }
}

#Preview {
    VStack(spacing: 16) {
        InlineErrorBannerView(message: "Incorrect username or password.")
        InlineErrorBannerView(message: nil)
    }
    .padding()
}
