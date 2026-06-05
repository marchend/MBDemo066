import SwiftUI

/// A static address-bar strip that mimics a browser header.
/// Shows `acmebank.okta.com` with a lock icon on the left and an Okta
/// logo (SF Symbol placeholder) on the right.
struct OktaHeaderView: View {
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 6) {
                Image(systemName: "lock.fill")
                    .font(.footnote)
                    .foregroundStyle(Color.secondary)

                Text("acmebank.okta.com")
                    .font(.footnote)
                    .foregroundStyle(Color.secondary)

                Spacer()

                // Okta "O" badge — using a circle SF symbol as a stand-in
                // for the Okta logo when the bundled asset is unavailable.
                ZStack {
                    Circle()
                        .fill(Color(red: 0, green: 0.498, blue: 1))
                        .frame(width: 22, height: 22)
                    Text("O")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.white)
                }
            }
            .padding(.horizontal, 16)
            .frame(height: 44)

            Divider()
        }
        .background(Color(.systemBackground))
    }
}

#Preview {
    OktaHeaderView()
}
