# AcmeBank — Agent & Developer Reference

## Project Overview
AcmeBank is an iOS 17+ banking app built in Swift/SwiftUI that gives customers
secure access to accounts, transactions, transfers, and card management via
Okta OIDC authentication. This repo currently contains the Hello-World scaffold;
all product features are delivered as separate Jira stories.

## Tech Stack
| Item | Value |
|---|---|
| Platform | iOS 17+ |
| Language | Swift 5.10 |
| UI Framework | SwiftUI |
| Architecture | MVVM + Coordinator (`NavigationStack`) |
| Auth | Okta OIDC (`okta-mobile-swift` 2.x) |
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
└── Resources/
    ├── Assets.xcassets/        # AppIcon stub (implemented)
    ├── PrivacyInfo.xcprivacy   # Privacy manifest (implemented)
    └── AcmeBank.entitlements   # Keychain access group stub (implemented)
AcmeBankTests/
└── AcmeBankTests.swift         # Trivial smoke test (implemented)
project.yml                     # XcodeGen spec (implemented)
setup.sh                        # One-shot project setup (implemented)
```

### Planned (full architecture)
```
AcmeBank/
├── App/             # RootView, AppCoordinator, Okta.plist
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
| `@main AcmeBankApp` + `ContentView` | ✅ implemented in this PR |
| XcodeGen `project.yml` | ✅ implemented in this PR |
| `.gitignore` + `setup.sh` | ✅ implemented in this PR |
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
| XCUITest target + critical-flow tests | ⏳ deferred — future PR |
| SwiftLint config (`.swiftlint.yml`) | ⏳ deferred — future PR |
| CI xcconfig / `API_BASE_URL` injection | ⏳ deferred — future PR |
| `Okta.plist.example` | ⏳ deferred — future PR |
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
