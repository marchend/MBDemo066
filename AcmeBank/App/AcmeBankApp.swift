import SwiftUI

@main
struct AcmeBankApp: App {

    /// The single, app-wide auth coordinator. Held as `@StateObject` so
    /// SwiftUI keeps it alive for the lifetime of the scene, and so
    /// `state` mutations re-render the root.
    ///
    /// Wire here, at the @main composition root — never inside a
    /// `View.init` (which is called on every parent re-render). The
    /// real `OktaAuthService` graph is constructed once here:
    /// `OktaAuthService` reads `OktaConfig.load()` on its own and pairs
    /// it with the real `SystemKeychainStore`.
    @StateObject private var coordinator = AppCoordinator(
        authService: OktaAuthService()
    )

    var body: some Scene {
        WindowGroup {
            ContentView(coordinator: coordinator)
        }
    }
}
