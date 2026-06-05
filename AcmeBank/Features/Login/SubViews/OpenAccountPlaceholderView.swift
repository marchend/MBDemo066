import SwiftUI

/// Placeholder sheet target for the "Open one" button on the Login screen.
/// Will be replaced by a real account-opening flow in a future story.
struct OpenAccountPlaceholderView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "building.columns")
                .font(.system(size: 48))
                .foregroundStyle(Color.acmeNavy)

            Text("Open Account")
                .font(.title2)
                .fontWeight(.semibold)

            Text("Coming Soon")
                .font(.body)
                .foregroundStyle(Color.secondary)
        }
        .padding()
        .accessibilityIdentifier("openAccountPlaceholder")
    }
}

#Preview {
    OpenAccountPlaceholderView()
}
