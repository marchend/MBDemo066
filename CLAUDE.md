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
│   ├── AcmeBankApp.swift       # @main entry point (implemented)
│   └── ContentView.swift       # Hello World view (implemented)
├── Info.plist.example          # Okta plist template (implemented; working copy .gitignored)
└── Resources/
    ├── Assets.xcassets/        # AppIcon stub (implemented)
    ├── PrivacyInfo.xcprivacy   # Privacy manifest (implemented)
    └── AcmeBank.entitlements   # Keychain access group stub (implemented)
AcmeBankTests/
└── AcmeBankTests.swift         # Trivial smoke test (implemented)
AcmeBankUITests/                # XCUITest target (implemented as an empty target;
                                #   the XCUITest sources land in a follow-on PR)
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
| `OktaConfig.swift` (runtime sentinel detection + `.load()`) | ⏳ deferred — follow-on PR |
| "Okta is not configured on this build" inline banner | ⏳ deferred — follow-on PR |
| XCUITest sources (`XCTSkipUnless` sign-in flow) | ⏳ deferred — follow-on PR |
| `AppCoordinator` + `RootView` (auth-state switching) | ⏳ deferred — future PR |
| Okta OIDC authentication (`AuthService`) | ⏳ deferred — future PR |
| `KeychainStore` / `UserSession` | ⏳ deferred — future PR |
| `APIClient` / `APIRouter` / `APIError` / `RequestInterceptor` | ⏳ deferred — future PR |
| Domain models (Account, Transaction, Customer) | ⏳ deferred — future PR |
| Repository protocols (`Domain/Repositories/`) | ⏳ deferred — future PR |
| Remote repositories (`Data/Remote/`) | ⏳ deferred — future PR |
| Mock repositories (`Data/Mock/`) | ⏳ deferred — future PR |
| Login feature (View + ViewModel + Coordinator) | ⏳ deferred — future PR |
| Home feature (View + ViewModel + Coordinator) | ⏳ deferred — future PR |
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

The **runtime half is still future work** (status table above). When you
implement `OktaConfig.load()`, it MUST detect the `__OKTA_NOT_CONFIGURED__`
sentinel that the script writes when any `OKTA_*` env var is unset and return
`.notConfigured(reason)` lazily — never `fatalError` / `preconditionFailure` /
force-unwrap on missing config at launch, or the app crashes on CI builds
that have no `OKTA_*` env vars set. The corresponding XCUITest MUST guard
the sign-in end-to-end test with `XCTSkipUnless(OktaConfig.load().isConfigured)`
so the test reports `XCTSkip`, not failure, on a CI build without env vars.

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
