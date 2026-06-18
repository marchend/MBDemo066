# AcmeBank — Agent & Developer Reference

## Project Overview
AcmeBank is an iOS 17+ banking app built in Swift/SwiftUI that gives customers
secure access to accounts, transactions, transfers, and card management via
Okta OIDC authentication. This repo currently contains the Hello-World scaffold
plus the Okta-DirectAuth *infrastructure layer* (SPM dep, `Inject Okta Config`
build script, `AcmeBankUITests` target, `AcmeBank/Info.plist.example`); all
product features and the Okta runtime layer are delivered as separate Jira
stories.

## Tech Stack
| Item | Value |
|---|---|
| Platform | iOS 17+ |
| Language | Swift 5.10 |
| UI Framework | SwiftUI |
| Architecture | MVVM + Coordinator (`NavigationStack`) |
| Auth | Okta OIDC (`okta-mobile-swift` 2.x, pinned to the 2.x minor line) |
| Networking | `URLSession` + async/await |
| DI | Constructor injection (no service locator) |
| Notifications | `NotificationCenter` (typed wrappers) |
| Project files | XcodeGen (`project.yml`) |
| Test framework | XCTest (unit) + XCUITest (critical flows) |
| Bundle ID | `com.acmebank.mobile` |
| Min Xcode | 16.0 |

## Getting Started
```bash
git clone <repo>
cd AcmeBank
./setup.sh        # installs xcodegen if missing, generates .xcodeproj, opens Xcode
```
Manual fallback:
```bash
brew install xcodegen && xcodegen generate && open AcmeBank.xcodeproj
```

## Running Tests
```bash
# Xcode: Product → Test (⌘U), scheme AcmeBank, iPhone 16 Simulator
xcodebuild test -scheme AcmeBank \
  -destination 'platform=iOS Simulator,name=iPhone 16'
```

## Key Directory Structure

### Current (bootstrap)
```
AcmeBank/
├── App/
│   ├── AcmeBankApp.swift       # @main entry point — wires AppCoordinator
│   ├── AppCoordinator.swift    # AuthState switching (signedOut ⇄ signedIn)
│   ├── RootCoordinator.swift   # AuthState → root view builder (Login / HomeDashboard)
│   └── ContentView.swift       # delegates to RootCoordinator.view(for:)
├── Core/
│   └── Auth/                   # OktaConfig, UserSession, SignedInUser, KeychainStore, AuthService (implemented)
├── Features/
│   ├── Home/                   # HomeDashboardView + ViewModel + PlaceholderDestinationView (signed-in root)
│   ├── Landing/                # LandingView (retained; no longer in the composition root)
│   └── Login/                  # LoginView + LoginViewModel + sub-views (implemented)
├── Info.plist.example          # Okta plist template (implemented; working copy .gitignored)
└── Resources/
    ├── AGENT.md / CLAUDE.md    # Per-module agent notes (identical pair)
    ├── Assets.xcassets/        # AppIcon stub (implemented)
    ├── PrivacyInfo.xcprivacy   # Privacy manifest (implemented)
    └── AcmeBank.entitlements   # Keychain access group stub (implemented)
AcmeBankTests/
├── AcmeBankTests.swift         # Trivial smoke test (implemented)
├── App/                        # AppCoordinator + RootCoordinator tests
├── Auth/                       # OktaConfig / UserSession / KeychainStore / AuthService tests (implemented)
└── Features/
    ├── Home/                   # HomeDashboard tests
    ├── Landing/                # LandingView tests
    └── Login/                  # LoginView + LoginViewModel tests (implemented)
AcmeBankUITests/                # XCUITest target
├── HomeDashboardUITests.swift  # `-uiTestSignedIn`-gated dashboard launch test
└── LoginFlowUITests.swift      # XCTSkipUnless-gated end-to-end sign-in flow
project.yml                     # XcodeGen spec (implemented)
setup.sh                        # One-shot project setup (implemented)
```

### Planned (full architecture)
```
AcmeBank/
├── App/             # RootView, AppCoordinator, OktaConfig.swift
├── Core/
│   ├── Auth/        # AuthService, KeychainStore, UserSession
│   ├── Networking/  # APIClient, APIRouter, APIError, RequestInterceptor
│   ├── Notifications/ # AppNotification, NotificationPublisher
│   └── Extensions/  # Decimal+Currency, Date+Greeting, String+Initials
├── Domain/
│   ├── Models/      # Account, Transaction, Customer, TransferRequest
│   └── Repositories/ # Protocol-only; no implementations here
├── Data/
│   ├── Remote/      # AccountAPIRepository, TransactionAPIRepository, …
│   └── Mock/        # MockAccountRepository, MockTransactionRepository, …
├── Features/
│   ├── Login/       # LoginCoordinator, LoginView, LoginViewModel
│   ├── Home/        # HomeCoordinator, HomeView, HomeViewModel + sub-views
│   ├── Accounts/    # (future)
│   ├── Transfer/    # (future)
│   └── Cards/       # (future)
└── DesignSystem/    # Colors.swift, Typography.swift, Assets.xcassets
AcmeBankTests/       # XCTest — ViewModel + Core unit tests
AcmeBankUITests/     # XCUITest — critical-flow end-to-end tests
```

## Planned Architecture

| Component | Status |
|---|---|
| `@main AcmeBankApp` + `ContentView` | ✅ implemented in the bootstrap PR |
| XcodeGen `project.yml` | ✅ implemented in the bootstrap PR |
| `.gitignore` + `setup.sh` | ✅ implemented in the bootstrap PR |
| `okta-mobile-swift` SPM dependency (pinned 2.x minor) | ✅ implemented in MD066 |
| `Inject Okta Config` pre-build script + `Info.plist.example` | ✅ implemented in MD066 |
| `AcmeBankUITests` target definition (empty) | ✅ implemented in MD066 |
| Login feature (View + ViewModel) | ✅ implemented in MD066-2 PR 1 |
| `OktaConfig.swift` (runtime sentinel detection + `.load()`) | ✅ implemented in MD066-2 PR 2 |
| `AuthService` / `OktaAuthService` (Okta DirectAuth) | ✅ implemented in MD066-2 PR 2 |
| `KeychainStore` / `UserSession` | ✅ implemented in MD066-2 PR 2 |
| `AppCoordinator` + auth-state switching + LandingView | ✅ implemented in MD066-2 PR 3 |
| "Okta is not configured on this build" inline banner | ✅ implemented in MD066-2 PR 3 |
| XCUITest sources (`XCTSkipUnless` sign-in flow) | ✅ implemented in MD066-2 PR 3 |
| Home dashboard (View + ViewModel + sub-views) | ✅ implemented in MD066-8 PR 1–3 |
| `RootCoordinator` + HomeDashboard wired as signed-in root | ✅ implemented in MD066-8 PR 4 |
| `APIClient` / `APIRouter` / `APIError` / `RequestInterceptor` | ⏳ deferred — future PR |
| Domain models (Account, Transaction, Customer) | ⏳ deferred — future PR |
| Repository protocols (`Domain/Repositories/`) | ⏳ deferred — future PR |
| Remote repositories (`Data/Remote/`) | ⏳ deferred — future PR |
| Mock repositories (`Data/Mock/`) | ⏳ deferred — future PR |
| Accounts / Transfer / Cards features | ⏳ deferred — future PR |
| Design system (Colors, Typography) | ⏳ deferred — future PR |
| `AppNotification` / `NotificationPublisher` | ⏳ deferred — future PR |
| Extensions (Decimal, Date, String) | ⏳ deferred — future PR |
| SwiftLint config (`.swiftlint.yml`) | ⏳ deferred — future PR |
| CI xcconfig / `API_BASE_URL` injection | ⏳ deferred — future PR |
| `Localizable.strings` | ⏳ deferred — future PR |

## Keychain Note (for feature agents)
Any Keychain query MUST include `kSecUseDataProtectionKeychain: true` to work in
CI's `CODE_SIGNING_ALLOWED=NO` simulator environment:
```swift
var query: [String: Any] = [
  kSecClass as String:                      kSecClassGenericPassword,
  kSecAttrService as String:                "com.acmebank.mobile",
  kSecAttrAccount as String:                "accessToken",
  kSecUseDataProtectionKeychain as String:  true,   // required for CI
]
```
`AcmeBank/Core/Auth/KeychainStore.swift` already enforces this for the three
Okta token slots (`acme.okta.idToken` / `acme.okta.accessToken` /
`acme.okta.refreshToken`); use it rather than re-implementing the SecItem
dance, and use the `KeychainStoring` protocol when you need to inject a
test double.

## Auth core (for feature agents)
`AcmeBank/Core/Auth/` ships the pure (UI-free) auth layer:

- `OktaConfig.load()` returns `.configured(...)` from a real `Info.plist`,
  `.notConfigured(reason)` when any of the four `OktaIssuer` / `OktaClientId` /
  `OktaRedirectUri` / `OktaScopes` keys is missing, sentinel, or malformed.
  NEVER traps — safe to call at app launch on a CI build with no `OKTA_*`
  env vars.
- `UserSession` decodes the OIDC ID-token claims (`sub` / `name` / `email` /
  `auth_time`) and pairs them with the access token. Throws a typed
  `DecodeError` on structural failures.
- `SignedInUser` is the first-name-shaped projection of `UserSession` that
  feature view-models consume (notably `HomeDashboardViewModel`). The
  composition root (`RootCoordinator`) does the `UserSession → SignedInUser`
  projection so feature code never sees the access token.
- `KeychainStore` (protocol `KeychainStoring`, prod impl `SystemKeychainStore`)
  persists tokens with `kSecUseDataProtectionKeychain: true` on every query.
- `AuthService` (protocol `AuthServicing`, prod impl `OktaAuthService`)
  wraps `okta-mobile-swift`'s `DirectAuthenticationFlow` behind a
  `DirectAuthenticationFlowProtocol` seam so unit tests don't hit the
  network. Constructor-injects both the `KeychainStoring` and a flow
  factory. **Critical invariant:** every error escaping `signIn` is an
  `AuthError` — keychain write failures are SWALLOWED inside `signIn`
  (they're a cache, not a hard requirement) and JWT decode failures map
  to `AuthError.invalidServerResponse`, NEVER to `.network`. The Login UI
  does `catch let e as AuthError`, so a non-`AuthError` escape produces
  a misleading "couldn't reach Okta" banner for a 200 OK.

## Composition root (for feature agents)
`AcmeBank/App/` wires the live auth flow at `@main`:

- `AcmeBankApp` instantiates one `AppCoordinator` as a `@StateObject`,
  passing it the real `OktaAuthService()`. Do NOT construct the
  coordinator inside a `View.init` — SwiftUI re-runs view inits on every
  parent re-render and you'd lose `state` mid-flight. The `@main` also
  honours the `-uiTestSignedIn` launch arg so `HomeDashboardUITests` can
  land on the dashboard without driving the Okta flow.
- `AppCoordinator` (@MainActor `ObservableObject`) owns `@Published
  state: AuthState` (`.signedOut` / `.signedIn(UserSession)`) and the
  shared `LoginViewModel`. Its `handleSignIn(...)` toggles
  `loginViewModel.isSigningIn`, awaits `authService.signIn(...)`,
  transitions to `.signedIn(session)` on success or routes the
  `AuthError` through `LoginViewModel.handleResult(_:)` on failure.
- `RootCoordinator` is the single seam that maps `AuthState` to a root
  view: `.signedOut → LoginView`, `.signedIn(session) → HomeDashboardView`
  wired to a fresh `HomeDashboardViewModel(repository:
  StubAccountsRepository(), user: SignedInUser(session:))`. When you add
  a new top-level destination, extend `RootCoordinator.Destination` and
  its `view(for:)` builder rather than adding a second switch in
  `ContentView`.
- `ContentView` is now a one-liner that calls
  `RootCoordinator.view(for: coordinator)`. There is intentionally NO
  no-op stub fallback here; re-introducing one would silently strand
  the real Okta wiring as dead code (the MD050-2 / MD066-2 lesson).
- `Features/Home/` hosts the dashboard module; `HomeDashboardView` owns
  its own `NavigationStack` (so `.navigationDestination(for:
  QuickAction.DestinationTag.self)` resolves), so `RootCoordinator`
  deliberately does NOT wrap it in an outer `NavigationStack`.

## Okta build config (for feature agents)
The build-time half of the Okta config is **already wired**: the four Okta
tenant values (`OktaIssuer`, `OktaClientId`, `OktaRedirectUri`, `OktaScopes`)
are injected into `AcmeBank/Info.plist` by the `Inject Okta Config` pre-build
script on the `AcmeBank` target, reading the four `OKTA_*` env vars from the
build machine — see the "Okta build configuration" section in `README.md` for
the env var names, the three setup methods (`launchctl setenv` / `~/.zshrc` +
`xed .` / per-command `xcodebuild` export), the `PhaseScriptExecution`
env-inheritance note, and the `.gitignore` / `Info.plist.example` security
pattern (the working `AcmeBank/Info.plist` must NEVER be tracked because the
script writes real tenant values into it).

The runtime half is implemented in `AcmeBank/Core/Auth/OktaConfig.swift`:
it detects the `__OKTA_NOT_CONFIGURED__` sentinel and returns
`.notConfigured(reason)` lazily — never `fatalError` / `preconditionFailure` /
force-unwrap on missing config at launch, so the app boots cleanly on CI
builds that have no `OKTA_*` env vars set. The end-to-end XCUITest
(`AcmeBankUITests/LoginFlowUITests.swift`) guards itself with
`XCTSkipUnless(OktaConfig.load().isConfigured)` plus a second skip on the
`OKTA_TEST_USERNAME` / `OKTA_TEST_PASSWORD` env vars, so the test reports
`XCTSkip`, not failure, on a CI build without env vars.

## Git Workflow

> **Default PR target branch: `develop`.** Every feature/refactor/docs PR
> opens against `develop`. PRs are only opened against `qa`, `uat`, or
> `main` for explicit promotion PRs.

**Branch model (`develop` → `qa` → `uat` → `main`):**

| Branch  | Role                                 | Receives PRs from              | Promotes to |
|---------|--------------------------------------|--------------------------------|-------------|
| develop | Default integration branch           | feature branches               | qa          |
| qa      | First quality gate                   | develop (promotion PR)         | uat         |
| uat     | Pre-prod acceptance                  | qa (promotion PR)              | main        |
| main    | Production / release tags            | uat (promotion PR)             | tagged only |

All feature PRs MUST target `develop`. Never open a feature PR against
`qa`, `uat`, or `main`. Promotions happen via dedicated promotion PRs.
