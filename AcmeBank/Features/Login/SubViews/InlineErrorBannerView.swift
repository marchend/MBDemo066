import SwiftUI

/// A reusable inline error strip.
/// Renders nothing when `message` is `nil`, so it takes no layout space on clean load.
/// Appears with the error copy when `message` is non-nil.
struct InlineErrorBannerView: View {
    let message: String?

    var body: some View {
        if let message {
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(Color.red)

                Text(message)
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
            .accessibilityIdentifier("inlineErrorBanner")
        }
    }
}

#Preview {
    VStack(spacing: 16) {
        InlineErrorBannerView(message: "Incorrect username or password.")
        InlineErrorBannerView(message: nil)
    }
    .padding()
}
