import Foundation
import Combine

/// Minimal identity snapshot the dashboard needs to render its header.
///
/// Deliberately a *small* value type rather than a re-export of
/// `UserSession` or the BFF's `Customer`:
///
///   - `UserSession` carries an OIDC access token and the full
///     display name; the dashboard greeting only needs the first
///     name and would otherwise pull the access token into a view
///     that has no business knowing it.
///   - The BFF `Customer` payload is a wire type. Coupling the
///     ViewModel to it would force every test fixture to construct
///     phone numbers, addresses, etc. that the greeting never reads.
///
/// Keep this type lean — if a future feature needs more identity
/// fields, prefer adding a sibling value type over fattening this one.
public struct SignedInUser: Equatable, Hashable {

    /// First name used verbatim in the greeting (e.g. `"Demo"` →
    /// "Good morning, Demo"). Caller is responsible for canonical
    /// case; the BFF already returns it correctly cased.
    public let firstName: String

    public init(firstName: String) {
        self.firstName = firstName
    }
}

/// Drives the Home dashboard's data + greeting state.
///
/// Pure logic — **no SwiftUI / UIKit imports**. The View binds to the
/// `@Published` properties via `ObservableObject`; everything here is
/// exercisable in a plain XCTest without a UIHostingController.
///
/// ## Dependencies (constructor-injected)
///
/// - `repository`: any `AccountsRepository`. Production wires the
///   real network-backed implementation; tests pass a fake (success
///   or throwing).
/// - `user`: the signed-in customer's identity snapshot (see
///   `SignedInUser`).
/// - `now`: closure returning "the current moment". Defaults to
///   `Date.init` so production gets the wall clock; tests pin it to
///   a literal `Date` so the greeting window is deterministic.
///
/// There is intentionally NO shared singleton — every dependency is
/// constructor-injected so the ViewModel is reusable across previews,
/// tests, and the real composition root.
///
/// ## State machine
///
/// The published properties form a small, deterministic state
/// machine driven by `load()`:
///
/// | Phase        | `isLoading` | `accounts`    | `errorMessage` |
/// |--------------|-------------|---------------|----------------|
/// | initial      | `false`     | `[]`          | `nil`          |
/// | loading      | `true`      | (unchanged)   | `nil`          |
/// | load success | `false`     | fetched list  | `nil`          |
/// | load failure | `false`     | (unchanged)   | non-`nil`      |
///
/// `errorMessage` is cleared at the start of every `load()` so a
/// retry doesn't surface the stale failure string while the new
/// request is in flight.
///
/// ## `@MainActor`
///
/// The class is `@MainActor`-isolated so SwiftUI bindings can read
/// `@Published` properties without crossing an actor boundary, and
/// all state mutations happen on the main queue. The repository call
/// is `await`-ed; `URLSession`'s async API hops off the main thread
/// internally, so the actor isolation does not block the network.
@MainActor
public final class HomeDashboardViewModel: ObservableObject {

    // MARK: - Published state

    /// Full salutation string (e.g. `"Good morning, Demo"`). Computed
    /// once at init time from `now()` and `user.firstName`. The
    /// dashboard mockup does NOT re-roll the greeting while the
    /// screen is on-screen (a user who lingers past 5 p.m. keeps the
    /// "Good afternoon" they opened with), so this is intentionally
    /// `let`-style rather than recomputed in `load()`.
    @Published public private(set) var greeting: String

    /// Accounts last fetched from the repository, in repository
    /// order. Empty until the first successful `load()`. A failed
    /// `load()` does NOT clear a previously-populated list — the
    /// dashboard would rather render the last known good data with
    /// an error banner than blank itself out on a transient blip.
    @Published public private(set) var accounts: [Account] = []

    /// `true` while a `load()` is in flight. The View binds this to
    /// a progress indicator / skeleton row.
    @Published public private(set) var isLoading: Bool = false

    /// Non-`nil` when the last `load()` threw. Cleared at the start
    /// of every new `load()`.
    @Published public private(set) var errorMessage: String?

    // MARK: - Dependencies

    private let repository: AccountsRepository
    private let user: SignedInUser
    private let now: () -> Date

    // MARK: - Init

    /// - Parameters:
    ///   - repository: data source for `accounts`. Constructor-
    ///     injected; no singletons.
    ///   - user:       identity snapshot used by the greeting.
    ///   - now:        clock for the greeting window. Defaults to
    ///                 the system clock; tests inject a fixed
    ///                 `Date` so the window is deterministic.
    public init(
        repository: AccountsRepository,
        user: SignedInUser,
        now: @escaping () -> Date = Date.init
    ) {
        self.repository = repository
        self.user       = user
        self.now        = now
        self.greeting   = GreetingProvider.greeting(
            for:       now(),
            firstName: user.firstName
        )
    }

    // MARK: - Actions

    /// Fetches accounts from the repository and updates the published
    /// state.
    ///
    /// Always:
    /// - Sets `isLoading = true` at entry and `false` at exit (even
    ///   on failure).
    /// - Clears `errorMessage` at entry so a retry doesn't show the
    ///   previous failure string while the new request is in flight.
    ///
    /// On success: replaces `accounts` with the fetched list.
    /// On failure: sets `errorMessage` and leaves `accounts`
    /// unchanged (see state-machine doc above).
    public func load() async {
        isLoading    = true
        errorMessage = nil

        defer { isLoading = false }

        do {
            let fetched = try await repository.fetchAccounts()
            accounts    = fetched
        } catch {
            errorMessage = "Couldn't load your accounts. Please try again."
        }
    }
}
