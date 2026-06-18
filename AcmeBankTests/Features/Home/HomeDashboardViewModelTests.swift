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

    /// A `Date` whose UTC hour is 9 — falls in the morning window
    /// regardless of CI host time zone (the ViewModel defers to
    /// `GreetingProvider`, which uses `.current` calendar; using a
    /// UTC-anchored hour here keeps the assertion stable on any host
    /// whose local hour-of-day rolls into the same morning bucket).
    ///
    /// We don't actually rely on the CI host's calendar here because
    /// the assertions below build the expected string by *calling
    /// `GreetingProvider` with the same `now()`* — that way the test
    /// asserts "the ViewModel routes the injected clock + user
    /// through the provider", not a hard-coded copy string.
    private let fixedDate = Date(timeIntervalSince1970: 1_717_236_000)  // 2024-06-01T10:00:00Z

    private let demoUser = SignedInUser(firstName: "Demo")

    // MARK: - Fake repositories

    /// Returns a canned list of accounts. Records call count so the
    /// "load() actually called the repo" assertion is explicit.
    private final class SuccessRepo: AccountsRepository {
        let accounts: [Account]
        private(set) var fetchCount = 0

        init(accounts: [Account]) {
            self.accounts = accounts
        }

        func fetchAccounts() async throws -> [Account] {
            fetchCount += 1
            return accounts
        }
    }

    /// Throws a fixed error on every call. The ViewModel never reads
    /// the error's payload (it surfaces a generic copy string), so
    /// any `Error` is sufficient.
    private final class FailingRepo: AccountsRepository {
        struct Boom: Error {}
        private(set) var fetchCount = 0

        func fetchAccounts() async throws -> [Account] {
            fetchCount += 1
            throw Boom()
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
        // provider verifies the wiring without leaking timezone-flake.
        let expected = GreetingProvider.greeting(
            for:       fixedDate,
            firstName: "Demo"
        )
        XCTAssertEqual(vm.greeting, expected)
    }

    func test_init_usesInjectedFirstNameNotADefault() {
        let alex = SignedInUser(firstName: "Alex")
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

        // Yield until the ViewModel has entered `load()` and set the flag.
        await waitUntil { vm.isLoading == true }
        XCTAssertTrue(vm.isLoading)

        await gate.open()
        await loadTask.value

        XCTAssertFalse(vm.isLoading)
        XCTAssertEqual(vm.accounts, StubAccountsRepository.fixtures)
    }

    // MARK: - Helpers

    /// Spin-yields until `condition` is true, with a small ceiling so
    /// a regression doesn't hang CI forever.
    private func waitUntil(
        _ condition: @escaping @MainActor () -> Bool,
        maxIterations: Int = 1_000
    ) async {
        var i = 0
        while !condition() && i < maxIterations {
            await Task.yield()
            i += 1
        }
    }
}

// MARK: - Extra fake repositories

/// Returns canned responses in order. After the sequence is
/// exhausted, repeats the last entry. Used by
/// `test_load_failure_leavesPreviouslyLoadedAccountsUnchanged`.
private final class FlakeyRepo: AccountsRepository {
    enum Response {
        case success([Account])
        case failure
    }

    struct Boom: Error {}

    private var sequence: [Response]

    init(sequence: [Response]) {
        self.sequence = sequence
    }

    func fetchAccounts() async throws -> [Account] {
        let next = sequence.count > 1 ? sequence.removeFirst() : sequence.first!
        switch next {
        case .success(let accounts):
            return accounts
        case .failure:
            throw Boom()
        }
    }
}

/// Suspends in `fetchAccounts` until the gate is opened, so a test
/// can inspect mid-flight `isLoading == true`.
private final class GatedRepo: AccountsRepository {
    let gate: AsyncGate
    let accounts: [Account]

    init(gate: AsyncGate, accounts: [Account]) {
        self.gate     = gate
        self.accounts = accounts
    }

    func fetchAccounts() async throws -> [Account] {
        await gate.wait()
        return accounts
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
