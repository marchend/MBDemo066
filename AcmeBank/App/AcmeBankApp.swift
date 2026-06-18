import SwiftUI

@main
struct AcmeBankApp: App {

    /// The single, app-wide auth coordinator. Held as `@StateObject` so
    /// SwiftUI keeps it alive for the lifetime of the scene, and so
    /// `state` mutations re-render the root.
    ///
    /// Wire here, at the @main composition root \u2014 never inside a
    /// `View.init` (which is called on every parent re-render). The
    /// real `OktaAuthService` graph is constructed once here:
    /// `OktaAuthService` reads `OktaConfig.load()` on its own and pairs
    /// it with the real `SystemKeychainStore`.
    @StateObject private var coordinator = AcmeBankApp.makeCoordinator()

    var body: some Scene {
        WindowGroup {
            ContentView(coordinator: coordinator)
        }
    }

    // MARK: - Composition

    /// Builds the app-wide coordinator.
    ///
    /// Honours the `-uiTestSignedIn` launch argument so the
    /// `HomeDashboardUITests` XCUITest can land directly on the
    /// signed-in dashboard without driving the Okta sign-in flow
    /// (which the CI runner can't complete without real tenant env
    /// vars \u2014 see `LoginFlowUITests` for the env-var skip gates).
    ///
    /// When the launch arg is present we still wire the same
    /// `OktaAuthService` as production (so any sign-out path stays
    /// real), but we pre-seed `state = .signedIn(stubSession)` so the
    /// dashboard is what shows on launch. The stub session uses
    /// stable, non-PII values (`"Demo Person"` / a fixture email) so
    /// the UI-test assertions can pin them.
    ///
    /// Production launches see `state = .signedOut` and the login
    /// screen, as before \u2014 the launch arg is only ever passed by the
    /// XCUITest target.
    private static func makeCoordinator() -> AppCoordinator {
        let coord = AppCoordinator(authService: OktaAuthService())
        if CommandLine.arguments.contains("-uiTestSignedIn") {
            coord.applyTestSignedInState(session: stubUITestSession())
        }
        return coord
    }

    /// Stub session used by `HomeDashboardUITests`. Values are stable
    /// so the test can pin the greeting first name (`"Demo"`). Never
    /// used outside the UI-test path \u2014 the access token is the empty
    /// string, so an inadvertent network call would 401 immediately
    /// rather than impersonating a real user.
    private static func stubUITestSession() -> UserSession {
        UserSession(
            userId:        "ui-test-user",
            displayName:   "Demo Person",
            email:         "demo.person@example.com",
            accessToken:   "",
            authTimestamp: Date(timeIntervalSince1970: 1_700_000_000),
            deviceName:    "UITest Simulator"
        )
    }
}
