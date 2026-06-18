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
    /// ## Why `#if targetEnvironment(simulator)`?
    /// The launch-arg branch is a documented auth-bypass: it skips
    /// Okta and lands on `HomeDashboardView` with a stub session.
    /// Shipping that branch in a device / App-Store binary would be
    /// a meaningful security risk \u2014 any tool that can inject launch
    /// arguments (a jailbreak tweak, an MDM payload, a paired
    /// `xcrun devicectl` invocation) could trip it. `#if DEBUG`
    /// doesn't help because XCUITests run against the Release-config
    /// app bundle, but `targetEnvironment(simulator)` is a
    /// **compile-time** condition that strips the branch from every
    /// device build (Debug or Release) while preserving it for the
    /// CI Simulator runs where `HomeDashboardUITests` actually
    /// executes. Production launches see `state = .signedOut` and
    /// the login screen, as before.
    private static func makeCoordinator() -> AppCoordinator {
        let coord = AppCoordinator(authService: OktaAuthService())
        #if targetEnvironment(simulator)
        if CommandLine.arguments.contains("-uiTestSignedIn") {
            coord.applyTestSignedInState(session: stubUITestSession())
        }
        #endif
        return coord
    }

    #if targetEnvironment(simulator)
    /// Stub session used by `HomeDashboardUITests`. Values are stable
    /// so the test can pin the greeting first name (`"Demo"`). Never
    /// used outside the UI-test path \u2014 the access token is the empty
    /// string, so an inadvertent network call would 401 immediately
    /// rather than impersonating a real user. Compiled in only on
    /// Simulator builds; the symbol does not exist in device or
    /// App-Store binaries.
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
    #endif
}
