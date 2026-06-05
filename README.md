# AcmeBank — iOS Banking App

AcmeBank is an iOS 17+ banking app built with Swift and SwiftUI, providing
customers with secure access to accounts, transactions, transfers, and card
management via Okta OIDC authentication.

## Quick Start

```bash
git clone <repo>
cd AcmeBank
./setup.sh
```

`setup.sh` installs [XcodeGen](https://github.com/yonaskolb/XcodeGen) if
missing, generates `AcmeBank.xcodeproj` from `project.yml`, and opens it in
Xcode.

**Manual fallback** (for environments that block shell scripts):
```bash
brew install xcodegen
xcodegen generate
open AcmeBank.xcodeproj
```

## Running Tests

```bash
xcodebuild test -scheme AcmeBank \
  -destination 'platform=iOS Simulator,name=iPhone 16'
```

Or in Xcode: **Product → Test** (⌘U).

## Project Structure

The Xcode project is **generated** from `project.yml` using XcodeGen — never
edit `project.pbxproj` directly. Drop new `.swift` files into `AcmeBank/` or
`AcmeBankTests/` and re-run `xcodegen generate`; the directory glob picks them
up automatically.

See [CLAUDE.md](CLAUDE.md) for full architecture documentation.

## Tech Stack

- **Platform:** iOS 17+, Swift 5.10
- **UI:** SwiftUI + MVVM + Coordinator (`NavigationStack`)
- **Auth:** Okta OIDC (`okta-mobile-swift`)
- **Networking:** `URLSession` + async/await
- **Tests:** XCTest (unit) + XCUITest (critical flows)
