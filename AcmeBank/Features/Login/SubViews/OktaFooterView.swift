import SwiftUI

/// "Secured by Okta" footer strip displayed at the bottom of the login screen.
struct OktaFooterView: View {
    var body: some View {
        VStack(spacing: 0) {
            Divider()

            HStack(spacing: 4) {
                Spacer()

                Text("Secured by ")
                    .font(.footnote)
                    .foregroundStyle(Color.secondary)

                // Okta logo badge
                ZStack {
                    Circle()
                        .fill(Color(red: 0, green: 0.498, blue: 1))
                        .frame(width: 18, height: 18)
                    Text("O")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.white)
                }

                Text("Okta")
                    .font(.footnote)
                    .fontWeight(.semibold)
                    .foregroundStyle(Color(red: 0, green: 0.498, blue: 1))

                Spacer()
            }
            .frame(height: 44)
        }
        .background(Color(.systemBackground))
    }
}

#Preview {
    OktaFooterView()
}
