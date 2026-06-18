import SwiftUI

/// Dashboard greeting strip — the two-line salutation from the
/// mockup:
///
/// ```
/// Good morning,
/// Demo
/// ```
///
/// Pure presentational: takes the salutation prefix (line 1) and the
/// customer's first name (line 2) already split by
/// `HomeDashboardViewModel`. The ViewModel computes the window
/// ("morning" / "afternoon" / "evening") and pins both strings once
/// at init time; this view never re-rolls them.
///
/// ## Why two strings, not one
/// The acceptance criteria for MD066-8 specify two visually-distinct
/// lines: line 1 in a regular subheadline weight, line 2 in a large
/// bold weight. A single pre-composed `"Good morning, Demo"` would
/// render as one line in one style, missing the mockup. Splitting
/// the two strings at the ViewModel boundary lets each line carry
/// its own font modifier here without re-parsing a composed string.
struct GreetingHeader: View {

    /// Line 1 — the time-of-day salutation with trailing comma,
    /// e.g. `"Good morning,"`.
    let salutation: String

    /// Line 2 — the customer's first name, e.g. `"Demo"`.
    let firstName: String

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(salutation)
                    .font(.subheadline)
                    .fontWeight(.regular)
                    .foregroundStyle(Color.secondary)
                    .accessibilityIdentifier("dashboard.greeting.salutation")

                Text(firstName)
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundStyle(Color.primary)
                    .accessibilityIdentifier("dashboard.greeting.firstName")
            }
            // Single composed VoiceOver string so the screen reader
            // reads the two visual lines as one natural-sounding
            // sentence: "Good morning, Demo".
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(salutation) \(firstName)")
            .accessibilityIdentifier("dashboard.greeting")

            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.top, 4)
    }
}

#Preview {
    GreetingHeader(salutation: "Good morning,", firstName: "Demo")
}
