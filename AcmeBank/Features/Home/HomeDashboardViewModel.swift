import Foundation
import Combine

/// Minimal identity snapshot the dashboard needs to render its header
/// and Signed-In Card.
///
/// Deliberately a *small* value type rather than a re-export of
/// `UserSession` or the BFF's `Customer`:
///
///   - `UserSession` carries an OIDC access token; the dashboard never
///     needs that token and would otherwise pull it into a view that
///     has no business knowing it.
///   - The BFF `Customer` payload is a wire type. Coupling the
///     ViewModel to it would force every test fixture to construct
///     phone numbers, addresses, etc. that the dashboard never reads.
///
/// The fields here are exactly the ones the current story's
/// acceptance criteria require — the header greeting's first name,
/// and the Signed-In Card's avatar initials (first + last name), full
/// name label (first + last name), and email. Keep this type lean —
/// if a future feature needs more identity fields, prefer adding a
/// sibling value type over fattening this one.
public struct SignedInUser: Equatable, Hashable {

    /// First name used verbatim in the greeting (e.g. `"Demo"` →
    /// "Good morning, Demo") and as the first half of the Signed-In
    /// Card's avatar initials / full-name label. Caller is responsible
    /// for canonical case; the BFF already returns it correctly cased.
    public let firstName: String

    /// Last name used as the second half of the Signed-In Card's
    /// avatar initials (`firstName[0] + lastName[0]`) and the full
    /// name label (`"\(firstName) \(lastName)"`). Canonical case is
    /// the caller's responsibility, as for `firstName`.
    public let lastName: String

    /// Email address shown on the Signed-In Card. Surfaced verbatim
    /// from the BFF `Customer` payload — the ViewModel does not
    /// validate or normalise it.
    public let email: String

    public init(firstName: String, lastName: String, email: String) {
        self.firstName = firstName
        self.lastName  = lastName
        self.email     = email
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
/// ## Concurrent `load()` calls
///
/// SwiftUI can drive two `load()` calls in rapid succession — e.g.
/// `.task` and `.onAppear` firing in the same render cycle, or a
/// pull-to-refresh tapping while an auto-refresh is mid-flight.
/// `@MainActor` serialises individual writes, but the network
/// responses race independently: a slow first response could
/// overwrite a fast second response's fresh data. `load()` therefore
/// cancels any in-flight task before starting a new one, so only the
/// most recent invocation can publish a result.
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

    // MARK: - In-flight load coordination

    /// Currently-running load, if any. A fresh `load()` cancels this
    /// before starting so two rapid invocations cannot race their
    /// responses against each other. See the class-level doc comment
    /// for the full rationale.
    private var loadTask: Task<Void, Never>?

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
        self.greeting   = now().greeting(firstName: user.firstName)
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
    /// - Cancels any in-flight `load()` before starting, so a slow
    ///   prior response cannot overwrite this call's fresh data.
    ///
    /// On success: replaces `accounts` with the fetched list.
    /// On failure: sets `errorMessage` and leaves `accounts`
    /// unchanged (see state-machine doc above). A `CancellationError`
    /// is treated as neither success nor failure — the cancelled
    /// call's state is left untouched so the superseding `load()`
    /// owns the final values.
    ///
    /// The call `await`-s the in-flight task to completion, so
    /// existing callers (and tests) that `await vm.load()` continue
    /// to observe the same "returns when the fetch is done" contract.
    public func load() async {
        loadTask?.cancel()
        let task = Task { [weak self] in
            await self?.performLoad()
        }
        loadTask = task
        await task.value
    }

    /// Body of `load()`. Split out so cancellation lives in `load()`
    /// (which is the public-facing entrypoint) and the actual state
    /// mutation lives in a single linear method.
    private func performLoad() async {
        isLoading    = true
        errorMessage = nil

        defer { isLoading = false }

        do {
            let fetched = try await repository.fetchAccounts()
            // A superseding `load()` may have cancelled us while the
            // repository call was suspended — bail before publishing
            // stale data over the new call's results.
            guard !Task.isCancelled else { return }
            accounts = fetched
        } catch is CancellationError {
            // Superseded by a fresh load(); leave state alone so the
            // new call owns the final values.
            return
        } catch {
            guard !Task.isCancelled else { return }
            errorMessage = "Couldn't load your accounts. Please try again."
        }
    }
}
