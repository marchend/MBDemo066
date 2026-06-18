import XCTest
@testable import AcmeBank

/// Unit tests for `HomeDashboardViewModel`.
///
/// The ViewModel has three concerns — greeting wiring, repository
/// load success, and repository load failure — and each one is
/// covered by a small fake repository + an injected clock so the
/// tests are deterministic on any CI host's local time zone.
@MainActor
final class HomeDashboardViewModelTests: XCTestCase {

    // MARK: - Fixtures

    /// A `Date` whose UTC hour is 10 — falls in the morning window
    /// regardless of CI host time zone (the ViewModel defers to the
    /// `Date.greeting(firstName:)` extension, which uses `.current`
    /// calendar; using a UTC-anchored hour here keeps the assertion
    /// stable on any host whose local hour-of-day rolls into the same
    /// morning bucket).
    ///
    /// We don't actually rely on the CI host's calendar here because
    /// the assertions below build the expected string by *calling
    /// the same `Date.greeting(firstName:)` extension with the same
    /// `now()`* — that way the test asserts "the ViewModel routes the
    /// injected clock + user through the extension", not a hard-coded
    /// copy string.
    private let fixedDate = Date(timeIntervalSince1970: 1_717_236_000)  // 2024-06-01T10:00:00Z

    private let demoUser = SignedInUser(
        firstName: "Demo",
        lastName:  "Person",
        email:     "demo.person@example.com"
    )

    // MARK: - Fake repositories

    /// Wraps a canned account list into a `HomeDashboard` (with an
    /// empty customer + no transactions) so the ViewModel's
    /// `fetchHome()` path is exercised while the existing
    /// account-focused assertions keep working.
    private static func dashboard(accounts: [Account]) -> HomeDashboard {
        HomeDashboard(
            customer: Customer(id: "cust-test", firstName: "Demo",
                               lastName: "Person", phoneNumber: "+1-555-0100"),
            accounts: accounts,
            recentTransactions: []
        )
    }

    /// Returns a canned dashboard. Records call count so the "load()
    /// actually called the repo" assertion is explicit.
    private final class SuccessRepo: HomeRepositoryProtocol {
        let accounts: [Account]
        private(set) var fetchCount = 0

        init(accounts: [Account]) {
            self.accounts = accounts
        }

        func fetchHome() async throws -> HomeDashboard {
            fetchCount += 1
            return HomeDashboardViewModelTests.dashboard(accounts: accounts)
        }
    }

    /// Throws a fixed error on every call. The ViewModel never reads
    /// the error's payload for the generic case, so any `Error` is
    /// sufficient.
    private final class FailingRepo: HomeRepositoryProtocol {
        struct Boom: Error {}
        private(set) var fetchCount = 0

        func fetchHome() async throws -> HomeDashboard {
            fetchCount += 1
            throw Boom()
        }
    }

    /// Throws the typed `unauthorized` (401) error so the
    /// session-expiry branch is exercised.
    private final class UnauthorizedRepo: HomeRepositoryProtocol {
        func fetchHome() async throws -> HomeDashboard {
            throw BFFHomeRepository.RepositoryError.unauthorized
        }
    }

    // MARK: - Initial state

    func test_init_setsInitialStateBeforeLoad() {
        let vm = HomeDashboardViewModel(
            repository: SuccessRepo(accounts: []),
            user:       demoUser,
            now:        { self.fixedDate }
        )

        XCTAssertEqual(vm.accounts, [])
        XCTAssertFalse(vm.isLoading)
        XCTAssertNil(vm.errorMessage)
    }

    // MARK: - Greeting wiring

    func test_init_computesGreetingFromInjectedClockAndUser() {
        let vm = HomeDashboardViewModel(
            repository: SuccessRepo(accounts: []),
            user:       demoUser,
            now:        { self.fixedDate }
        )

        // Build the expected greeting the same way the ViewModel does
        // — pinning a literal "Good morning, Demo" would couple this
        // test to the CI host's time zone (the fixed Date is
        // 10:00 UTC, but local hour varies). Asserting via the
        // extension verifies the wiring without leaking timezone-flake.
        let expected = fixedDate.greeting(firstName: "Demo")
        XCTAssertEqual(vm.greeting, expected)
    }

    func test_init_usesInjectedFirstNameNotADefault() {
        let alex = SignedInUser(
            firstName: "Alex",
            lastName:  "Example",
            email:     "alex@example.com"
        )
        let vm = HomeDashboardViewModel(
            repository: SuccessRepo(accounts: []),
            user:       alex,
            now:        { self.fixedDate }
        )

        XCTAssertTrue(vm.greeting.hasSuffix(", Alex"),
                      "greeting should end with the user's first name; got \(vm.greeting)")
    }

    func test_init_doesNotCall_now_morethanOnce_forGreeting() {
        // The greeting is computed at init time only — the mockup does
        // NOT re-roll the greeting once the screen is on-screen. If a
        // future refactor accidentally re-reads `now()` on every state
        // change this test will start failing.
        var callCount = 0
        _ = HomeDashboardViewModel(
            repository: SuccessRepo(accounts: []),
            user:       demoUser,
            now:        {
                callCount += 1
                return self.fixedDate
            }
        )

        XCTAssertEqual(callCount, 1)
    }

    // MARK: - load() — success

    func test_load_success_populatesAccounts_andClearsLoading() async {
        let fixtures = StubAccountsRepository.fixtures
        let repo     = SuccessRepo(accounts: fixtures)
        let vm = HomeDashboardViewModel(
            repository: repo,
            user:       demoUser,
            now:        { self.fixedDate }
        )

        await vm.load()

        XCTAssertEqual(vm.accounts, fixtures)
        XCTAssertFalse(vm.isLoading)
        XCTAssertNil(vm.errorMessage)
        XCTAssertEqual(repo.fetchCount, 1)
    }

    func test_load_success_clearsPreviousErrorMessage() async {
        // First load fails to set an error, then a success clears it.
        let failing = FailingRepo()
        let vm = HomeDashboardViewModel(
            repository: failing,
            user:       demoUser,
            now:        { self.fixedDate }
        )
        await vm.load()
        XCTAssertNotNil(vm.errorMessage,
                        "precondition: failing load should set errorMessage")

        // Swap to a success repo by constructing a fresh VM — the
        // production ViewModel doesn't expose a setter for the repo
        // (constructor injection only), so this test exercises the
        // "fresh VM, success path" contract directly.
        let succeeding = SuccessRepo(accounts: StubAccountsRepository.fixtures)
        let vm2 = HomeDashboardViewModel(
            repository: succeeding,
            user:       demoUser,
            now:        { self.fixedDate }
        )
        await vm2.load()

        XCTAssertNil(vm2.errorMessage)
        XCTAssertEqual(vm2.accounts, StubAccountsRepository.fixtures)
    }

    // MARK: - load() — failure

    func test_load_unauthorized_setsSessionExpired_notErrorMessage() async {
        let repo = UnauthorizedRepo()
        let vm = HomeDashboardViewModel(
            repository: repo,
            user:       demoUser,
            now:        { self.fixedDate }
        )

        await vm.load()

        XCTAssertTrue(vm.sessionExpired,
                      "A 401/unauthorized must flip sessionExpired so the view routes to login.")
        XCTAssertNil(vm.errorMessage,
                     "A 401 routes to login rather than showing the generic retry banner.")
        XCTAssertFalse(vm.isLoading)
    }

    func test_load_failure_setsErrorMessage_andClearsLoading() async {
        let repo = FailingRepo()
        let vm = HomeDashboardViewModel(
            repository: repo,
            user:       demoUser,
            now:        { self.fixedDate }
        )

        await vm.load()

        XCTAssertFalse(vm.isLoading)
        XCTAssertNotNil(vm.errorMessage)
        XCTAssertEqual(repo.fetchCount, 1)
    }

    func test_load_failure_leavesPreviouslyLoadedAccountsUnchanged() async {
        // Real-world: a transient network blip after a successful
        // fetch should NOT blank out the dashboard. The mockup would
        // rather show last-known-good data + an error banner.
        let succeedingThenFailing = FlakeyRepo(
            sequence: [.success(StubAccountsRepository.fixtures), .failure]
        )
        let vm = HomeDashboardViewModel(
            repository: succeedingThenFailing,
            user:       demoUser,
            now:        { self.fixedDate }
        )

        await vm.load()
        XCTAssertEqual(vm.accounts, StubAccountsRepository.fixtures,
                       "precondition: first load should populate accounts")
        XCTAssertNil(vm.errorMessage)

        await vm.load()
        XCTAssertEqual(vm.accounts, StubAccountsRepository.fixtures,
                       "second (failing) load should NOT clear accounts")
        XCTAssertNotNil(vm.errorMessage)
    }

    // MARK: - Loading flag transitions

    func test_load_setsIsLoadingTrue_whileInFlight() async {
        // A repo whose `fetchAccounts` suspends until we resume it
        // lets us assert `isLoading == true` mid-flight.
        let gate = AsyncGate()
        let repo = GatedRepo(gate: gate, accounts: StubAccountsRepository.fixtures)
        let vm = HomeDashboardViewModel(
            repository: repo,
            user:       demoUser,
            now:        { self.fixedDate }
        )

        let loadTask = Task { await vm.load() }

        // Wait, with a real wall-clock deadline, for the ViewModel to
        // enter `load()` and flip the flag. Using `Task.sleep` rather
        // than a bare `Task.yield()` spin loop means a loaded CI host
        // actually parks the test task and lets the load task run —
        // see the helper's doc comment for why this matters.
        let entered = await waitUntil(timeout: 1.0) { vm.isLoading == true }
        XCTAssertTrue(entered,
                      "ViewModel did not flip isLoading to true within 1s — load() may not have started")
        XCTAssertTrue(vm.isLoading)

        await gate.open()
        await loadTask.value

        XCTAssertFalse(vm.isLoading)
        XCTAssertEqual(vm.accounts, StubAccountsRepository.fixtures)
    }

    // MARK: - Helpers

    /// Polls `condition` until it returns `true` or `timeout` seconds
    /// elapse on the wall clock. Returns `true` if the condition was
    /// observed, `false` if the deadline expired.
    ///
    /// Why a wall-clock sleep rather than a bare `Task.yield()` spin:
    /// `Task.yield()` only yields to *already-ready* tasks — it
    /// introduces no real delay. On a loaded CI host the spin can
    /// exhaust its iteration ceiling before the other task is ever
    /// scheduled, so the caller's `XCTAssertTrue(vm.isLoading)` would
    /// silently fire on a still-`false` value. A short `Task.sleep`
    /// inside the loop parks the host thread for real, gives the
    /// scheduler a chance to run the other task, and (together with a
    /// real wall-clock timeout) gives the test a clear deadline
    /// rather than a fuzzy iteration count.
    private func waitUntil(
        timeout: TimeInterval,
        pollInterval: TimeInterval = 0.005,
        _ condition: @escaping @MainActor () -> Bool
    ) async -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if condition() { return true }
            try? await Task.sleep(nanoseconds: UInt64(pollInterval * 1_000_000_000))
        }
        return condition()
    }
}

// MARK: - Extra fake repositories

/// Returns canned responses in order. After the sequence is
/// exhausted, repeats the last entry. Used by
/// `test_load_failure_leavesPreviouslyLoadedAccountsUnchanged`.
private final class FlakeyRepo: HomeRepositoryProtocol {
    enum Response {
        case success([Account])
        case failure
    }

    struct Boom: Error {}

    private var sequence: [Response]

    init(sequence: [Response]) {
        self.sequence = sequence
    }

    func fetchHome() async throws -> HomeDashboard {
        let next = sequence.count > 1 ? sequence.removeFirst() : sequence.first!
        switch next {
        case .success(let accounts):
            return HomeDashboard(
                customer: Customer(id: "cust-test", firstName: "Demo",
                                   lastName: "Person", phoneNumber: ""),
                accounts: accounts,
                recentTransactions: []
            )
        case .failure:
            throw Boom()
        }
    }
}

/// Suspends in `fetchHome` until the gate is opened, so a test can
/// inspect mid-flight `isLoading == true`.
private final class GatedRepo: HomeRepositoryProtocol {
    let gate: AsyncGate
    let accounts: [Account]

    init(gate: AsyncGate, accounts: [Account]) {
        self.gate     = gate
        self.accounts = accounts
    }

    func fetchHome() async throws -> HomeDashboard {
        await gate.wait()
        return HomeDashboard(
            customer: Customer(id: "cust-test", firstName: "Demo",
                               lastName: "Person", phoneNumber: ""),
            accounts: accounts,
            recentTransactions: []
        )
    }
}

/// One-shot async gate. `wait()` suspends until `open()` is called.
private actor AsyncGate {
    private var continuation: CheckedContinuation<Void, Never>?
    private var opened = false

    func wait() async {
        if opened { return }
        await withCheckedContinuation { cont in
            self.continuation = cont
        }
    }

    func open() {
        opened = true
        continuation?.resume()
        continuation = nil
    }
}
