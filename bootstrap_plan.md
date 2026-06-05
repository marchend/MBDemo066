# Bootstrap Plan — AcmeBank iOS

## In scope (this PR)

### Project name + tech stack decisions
- **App name:** AcmeBank
- **Platform:** iOS 17+, Swift 5.10, SwiftUI
- **Architecture:** MVVM + Coordinator (deferred to future PRs)
- **Project file mechanism:** XcodeGen (`project.yml`) — never a hand-crafted `.pbxproj`
- **Test framework:** XCTest (unit tests)
- **Bundle ID:** `com.acmebank.mobile`
- **Minimum Xcode:** 16.0

### Directory structure (bootstrap only)

```
AcmeBank/                         ← source root (XcodeGen glob: sources: [AcmeBank])
├── App/
│   └── AcmeBankApp.swift         ← @main SwiftUI entry point showing "AcmeBank"
├── Resources/
│   ├── Assets.xcassets/
│   │   ├── Contents.json
│   │   └── AppIcon.appiconset/
│   │       └── Contents.json
│   └── PrivacyInfo.xcprivacy
└── AcmeBank.entitlements
AcmeBankTests/
└── AcmeBankTests.swift           ← one trivial XCTest (proves test runner works)
project.yml                       ← XcodeGen spec
.gitignore
setup.sh
bootstrap_plan.md
CLAUDE.md
AGENT.md
README.md
```

### Files this PR creates
| File | Purpose |
|---|---|
| `project.yml` | XcodeGen project spec |
| `AcmeBank/App/AcmeBankApp.swift` | @main SwiftUI entry — shows "AcmeBank" text |
| `AcmeBank/Resources/Assets.xcassets/Contents.json` | Asset catalog metadata |
| `AcmeBank/Resources/Assets.xcassets/AppIcon.appiconset/Contents.json` | AppIcon stub (required by actool) |
| `AcmeBank/Resources/PrivacyInfo.xcprivacy` | Required-reason API privacy manifest |
| `AcmeBank/AcmeBank.entitlements` | Keychain access group stub |
| `AcmeBankTests/AcmeBankTests.swift` | Trivial XCTest — `ContentView()` initialises |
| `.gitignore` | iOS/XcodeGen standard ignores |
| `setup.sh` | One-shot: install xcodegen + generate + open |
| `CLAUDE.md` | Agent documentation |
| `AGENT.md` | Agent documentation (identical to CLAUDE.md) |
| `README.md` | Project readme |

### How to run locally
```
git clone <repo>
cd AcmeBank
./setup.sh   # installs xcodegen if missing, generates .xcodeproj, opens in Xcode
```
Manual fallback:
```
brew install xcodegen && xcodegen generate && open AcmeBank.xcodeproj
```

### How to run tests
In Xcode: Product → Test (⌘U), scheme `AcmeBank`, destination `iPhone 16 Simulator`.

Via command line:
```
xcodebuild test -scheme AcmeBank -destination 'platform=iOS Simulator,name=iPhone 16'
```

### Definition of Hello World
App launches and displays a centered "AcmeBank" text label on a white background.
One test (`test_contentView_initializes`) instantiates `ContentView` — proves the
test target compiles and links against the app module.

---

## Out of scope — deferred to future work

- **Authentication (Okta OIDC / `okta-mobile-swift`)** — future PR
- **AuthService / KeychainStore / UserSession** — future PR
- **Networking layer (APIClient, APIRouter, APIError, RequestInterceptor)** — future PR
- **Domain models (Account, Transaction, Customer, TransferRequest)** — future PR
- **Repository protocols (AccountRepository, TransactionRepository, CustomerRepository)** — future PR
- **Remote API repositories (AccountAPIRepository, etc.)** — future PR
- **Mock repositories (MockAccountRepository, etc.)** — future PR
- **MVVM + Coordinator pattern implementation** — future PR
- **AppCoordinator / RootView auth-state switching** — future PR
- **Login feature (LoginView, LoginViewModel, LoginCoordinator)** — future PR
- **Home feature (HomeView, HomeViewModel, HomeCoordinator, sub-views)** — future PR
- **Accounts, Transfer, Cards features** — future PRs
- **Design system tokens (Colors.swift, Typography.swift)** — future PR
- **Internal notifications (AppNotification, NotificationPublisher)** — future PR
- **Extensions (Decimal+Currency, Date+Greeting, String+Initials)** — future PR
- **XCUITest target and LoginUITests / TransferUITests** — future PR
- **SwiftLint configuration (.swiftlint.yml)** — future PR
- **CI xcconfig / API_BASE_URL injection** — future PR
- **Okta.plist.example** — future PR
- **Localizable.strings** — future PR
- **80% line coverage requirement** — tracked in feature stories
