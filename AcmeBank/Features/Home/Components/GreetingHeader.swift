import SwiftUI

/// Dashboard greeting strip — e.g. "Good morning, Demo".
///
/// Pure presentational: takes the already-composed greeting string
/// from `HomeDashboardViewModel.greeting`. The ViewModel computes the
/// window ("morning" / "afternoon" / "evening") and stitches the
/// first name in once at init time; this view never re-rolls it.
struct GreetingHeader: View {

    let greeting: String

    var body: some View {
        HStack {
            Text(greeting)
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundStyle(Color.primary)
                .accessibilityIdentifier("dashboard.greeting")

            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.top, 4)
    }
}

#Preview {
    GreetingHeader(greeting: "Good morning, Demo")
}
