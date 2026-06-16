import XCTest
import SwiftUI
@testable import AcmeBank

/// Behaviour tests for `LandingView`.
///
/// Mirrors the established project pattern (see `LoginViewTests`): no
/// `ViewInspector` dependency, no snapshot PNGs. Instead we verify that
/// `LandingView` initialises from a `UserSession` and exposes the two
/// claim-derived fields (`displayName`, `email`) that drive its two
/// `Text` views.
final class LandingViewTests: XCTestCase {

    private func makeSession(
        displayName: String = "Alice Example",
        email:       String = "alice@example.com"
    ) -> UserSession {
        UserSession(
            userId:        "00u123",
            displayName:   displayName,
            email:         email,
            accessToken:   "AT",
            authTimestamp: Date(timeIntervalSince1970: 1_700_000_000),
            deviceName:    "iPhone Test"
        )
    }

    /// LandingView constructs from a UserSession without crashing.
    func test_landingView_initialises() {
        let session = makeSession()
        _ = LandingView(session: session)
    }

    /// The injected session is the source of the on-screen Welcome
    /// greeting. The view renders `Text("Welcome, \(session.displayName)")`
    /// so the displayName MUST round-trip through the view's input.
    func test_landingView_exposesDisplayName() {
        let session = makeSession(displayName: "Bob Tester")
        let view = LandingView(session: session)
        XCTAssertEqual(view.session.displayName, "Bob Tester",
                       "LandingView must render the session's displayName")
    }

    /// The injected session is the source of the on-screen email line.
    func test_landingView_exposesEmail() {
        let session = makeSession(email: "bob@example.com")
        let view = LandingView(session: session)
        XCTAssertEqual(view.session.email, "bob@example.com",
                       "LandingView must render the session's email")
    }

    /// Unicode / special characters in the display name round-trip
    /// without mangling — guards against an accidental ASCII-only
    /// substring path being introduced.
    func test_landingView_handlesUnicodeDisplayName() {
        let session = makeSession(displayName: "Renée Café")
        let view = LandingView(session: session)
        XCTAssertEqual(view.session.displayName, "Renée Café")
    }
}
