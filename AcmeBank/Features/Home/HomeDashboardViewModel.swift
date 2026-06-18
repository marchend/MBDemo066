import Foundation
import Combine

/// View-model backing `HomeDashboardView`.
///
/// ## Responsibilities
/// - Computes the time-of-day greeting once at init from the injected
///   clock + user identity (so the greeting is populated before the
///   first `/v1/home` load returns).
/// - Fetches the full `HomeDashboard` (customer + accounts + recent
///   transactions) from the injected `HomeRepositoryProtocol` and
///   publishes it.
/// - Owns the `isLoading` / `errorMessage` flags the view binds to.
/// - Surfaces `sessionExpired` when the BFF rejects the token (401),
///   so the view can route back to login.
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
    /// dashboard does NOT re-roll the greeting while the screen is
    /// on-screen, so this is intentionally computed once rather than
    /// recomputed in `load()`.
    @Published public private(set) var greeting: String

    /// The signed-in customer from the most recent successful load.
    /// `nil` until the first `/v1/home` response arrives — the view
    /// falls back to the injected `user` for the greeting until then.
    @Published public private(set) var customer: Customer?

    /// Accounts last fetched, in repository order. Empty until the
    /// first successful `load()`. A failed `load()` does NOT clear a
    /// previously-populated list — the dashboard would rather render
    /// the last known good data with an error banner than blank
    /// itself out on a transient blip.
    @Published public private(set) var accounts: [Account] = []

    /// Recent transactions from the most recent successful load,
    /// newest-first (the BFF already returns them in that order).
    @Published public private(set) var recentTransactions: [Transaction] = []

    /// `true` while a `load()` is in flight. The View binds this to a
    /// progress indicator.
    @Published public private(set) var isLoading: Bool = false

    /// Non-`nil` when the last `load()` threw a non-auth error.
    /// Cleared at the start of every new `load()`.
    @Published public private(set) var errorMessage: String?

    /// Set to `true` when the BFF rejects the access token (401 /
    /// `unauthorized`). The view observes this and calls `onSignOut`
    /// to route back to login — an expired token cannot be retried in
    /// place.
    @Published public private(set) var sessionExpired: Bool = false

    /// First name to render in the greeting header: the freshly-loaded
    /// `customer.firstName` once available, otherwise the injected
    /// `user.firstName` so the header isn't blank before the first
    /// load returns.
    public var greetingFirstName: String {
        if let name = customer?.firstName, !name.isEmpty {
            return name
        }
        return user.firstName
    }

    // MARK: - Dependencies

    private let repository: HomeRepositoryProtocol
    private let user: SignedInUser
    private let now: () -> Date

    // MARK: - In-flight load coordination

    /// Currently-running load, if any. A fresh `load()` cancels this
    /// before starting so two rapid invocations cannot race their
    /// responses against each other.
    private var loadTask: Task<Void, Never>?

    // MARK: - Init

    /// - Parameters:
    ///   - repository: data source for the `/v1/home` payload.
    ///     Constructor-injected; no singletons.
    ///   - user:       identity snapshot used for the greeting before
    ///                 the first load returns.
    ///   - now:        clock for the greeting window. Defaults to the
    ///                 system clock; tests inject a fixed `Date` so the
    ///                 window is deterministic.
    public init(
        repository: HomeRepositoryProtocol,
        user: SignedInUser,
        now: @escaping () -> Date = Date.init
    ) {
        self.repository = repository
        self.user       = user
        self.now        = now

        self.greeting = now().greeting(firstName: user.firstName)
    }

    // MARK: - Actions

    /// Fetches the dashboard from the repository and updates the
    /// published state.
    ///
    /// Always:
    /// - Sets `isLoading = true` at entry and `false` at exit (even on
    ///   failure).
    /// - Clears `errorMessage` at entry so a retry doesn't show the
    ///   previous failure string while the new request is in flight.
    /// - Cancels any in-flight `load()` before starting, so a slow
    ///   prior response cannot overwrite this call's fresh data.
    ///
    /// On success: replaces `customer` / `accounts` /
    /// `recentTransactions` with the fetched payload.
    /// On `unauthorized`: sets `sessionExpired = true` (the view
    /// routes to login).
    /// On any other failure: sets `errorMessage` and leaves the
    /// last-known-good data unchanged. A `CancellationError` is
    /// treated as neither success nor failure.
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
            let home = try await repository.fetchHome()
            try Task.checkCancellation()
            customer           = home.customer
            accounts           = home.accounts
            recentTransactions = home.recentTransactions
        } catch is CancellationError {
            // Superseded by a fresh load() — leave state to the
            // newer call.
            return
        } catch BFFHomeRepository.RepositoryError.unauthorized {
            // Token rejected / expired — can't retry in place; the
            // view routes back to login.
            sessionExpired = true
        } catch {
            errorMessage = "We couldn’t load your dashboard. Please try again."
        }
    }
}
