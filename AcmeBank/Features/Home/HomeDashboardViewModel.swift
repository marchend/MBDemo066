import Foundation
import Combine

/// View-model backing `HomeDashboardView`.
///
/// ## Responsibilities
/// - Computes the time-of-day greeting once at init from the injected
///   clock + user identity.
/// - Fetches accounts from the injected `AccountsRepository` and
///   publishes them in repository order.
/// - Owns the `isLoading` / `errorMessage` flags the view binds to.
/// - Cancels any in-flight `load()` when a fresh `load()` is kicked
///   so two rapid invocations cannot race their responses against
///   each other.
///
/// ## Threading
/// `@MainActor` annotated so the view can read and write the
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
    ///
    /// Retained as the single-string form so existing call-sites and
    /// tests continue to work. The dashboard view itself renders the
    /// two-line mockup layout via `greetingSalutation` +
    /// `greetingFirstName` below.
    @Published public private(set) var greeting: String

    /// Line 1 of the two-line dashboard greeting — the time-of-day
    /// salutation with a trailing comma, e.g. `"Good morning,"`.
    ///
    /// Surfaced as its own property so `GreetingHeader` can render
    /// the two lines of the mockup with different styles (regular
    /// weight subheadline for the salutation, large bold for the
    /// name) without re-parsing a composed string. See
    /// `Date+Greeting` for the time-of-day window logic that backs
    /// the prefix here.
    @Published public private(set) var greetingSalutation: String

    /// Line 2 of the two-line dashboard greeting — the customer's
    /// first name as rendered, e.g. `"Demo"`. Pulled verbatim from
    /// `user.firstName`; the BFF returns canonical case.
    @Published public private(set) var greetingFirstName: String

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

        let instant     = now()
        let prefix      = instant.greetingPrefix()
        self.greeting           = instant.greeting(firstName: user.firstName)
        self.greetingSalutation = "\(prefix),"
        self.greetingFirstName  = user.firstName
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
    public func load() async {
        // Cancel any in-flight load so its late response cannot
        // clobber the state we're about to set.
        loadTask?.cancel()

        let task = Task { [weak self] in
            guard let self else { return }
            await self.performLoad()
        }
        loadTask = task
        await task.value
    }

    private func performLoad() async {
        isLoading    = true
        errorMessage = nil

        defer { isLoading = false }

        do {
            let fetched = try await repository.fetchAccounts()
            try Task.checkCancellation()
            accounts = fetched
        } catch is CancellationError {
            // Superseded by a fresh load() — leave state to the
            // newer call.
            return
        } catch {
            errorMessage = "We couldn’t load your accounts. Please try again."
        }
    }
}
