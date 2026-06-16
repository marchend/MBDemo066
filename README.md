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
edit `project.pbxproj` directly. Drop new `.swift` files into `AcmeBank/`,
`AcmeBankTests/`, or `AcmeBankUITests/` and re-run `xcodegen generate`; the
directory glob picks them up automatically.

See [CLAUDE.md](CLAUDE.md) for full architecture documentation.

## Tech Stack

- **Platform:** iOS 17+, Swift 5.10
- **UI:** SwiftUI + MVVM + Coordinator (`NavigationStack`)
- **Auth:** Okta OIDC (`okta-mobile-swift`)
- **Networking:** `URLSession` + async/await
- **Tests:** XCTest (unit) + XCUITest (critical flows)

## Okta build configuration

Okta tenant values are **not** committed to the repo. They are injected into
the built `Info.plist` at build time by the `Inject Okta Config` Run Script
phase on the `AcmeBank` target, reading from environment variables on the
build machine.

### Required environment variables

| Variable             | Example                                          |
|----------------------|--------------------------------------------------|
| `OKTA_ISSUER`        | `https://dev-123456.okta.com/oauth2/default`     |
| `OKTA_CLIENT_ID`     | `0oabcdefghIJKLMNOPqr`                           |
| `OKTA_REDIRECT_URI`  | `com.acmebank.mobile:/callback`                  |
| `OKTA_SCOPES`        | `openid profile email offline_access`            |

When all four are set, `OktaConfig.load()` returns `.configured(...)` at
runtime and DirectAuth runs against your real Okta tenant. When **any** is
unset, the Run Script writes the sentinel string `__OKTA_NOT_CONFIGURED__`
into the Info.plist for that key (it **never** fails the build), `OktaConfig`
returns `.notConfigured(reason)`, the app launches showing the "Okta is not
configured on this build" banner, and the XCUITest covering the sign-in flow
is skipped via `XCTSkipUnless`.

### Three ways to set the env vars

Xcode and `xcodebuild` only see env vars through specific channels — pick the
one that matches how you launch the build.

1. **Xcode launched from Finder / Dock** — use `launchctl setenv`. Job-level
   env vars set this way are inherited by GUI apps spawned by `launchd`.
   ```bash
   launchctl setenv OKTA_ISSUER       "https://dev-123456.okta.com/oauth2/default"
   launchctl setenv OKTA_CLIENT_ID    "0oabcdefghIJKLMNOPqr"
   launchctl setenv OKTA_REDIRECT_URI "com.acmebank.mobile:/callback"
   launchctl setenv OKTA_SCOPES       "openid profile email offline_access"
   ```
   Then launch Xcode from the Dock as usual. Survives until reboot.

2. **Xcode launched from a fresh shell** — `export` in `~/.zshrc` and use
   `xed .` so Xcode inherits the shell environment.
   ```bash
   # ~/.zshrc
   export OKTA_ISSUER="https://dev-123456.okta.com/oauth2/default"
   export OKTA_CLIENT_ID="0oabcdefghIJKLMNOPqr"
   export OKTA_REDIRECT_URI="com.acmebank.mobile:/callback"
   export OKTA_SCOPES="openid profile email offline_access"
   ```
   ```bash
   source ~/.zshrc
   cd path/to/AcmeBank && xed .
   ```

3. **Scripted / CI invocations of `xcodebuild`** — pass the env vars on the
   same command line so they're in `xcodebuild`'s own process environment:
   ```bash
   OKTA_ISSUER="$OKTA_ISSUER" \
   OKTA_CLIENT_ID="$OKTA_CLIENT_ID" \
   OKTA_REDIRECT_URI="$OKTA_REDIRECT_URI" \
   OKTA_SCOPES="$OKTA_SCOPES" \
   xcodebuild build -scheme AcmeBank \
     -destination 'platform=iOS Simulator,name=iPhone 16'
   ```

### Why the command-line-export form is the only reliable CI pattern

`xcodebuild` runs Run Script build phases inside `PhaseScriptExecution`
subshells. Those subshells do **not** inherit arbitrary job-level shell env
vars from the GitHub Actions runner / Jenkins job — only the variables that
are in `xcodebuild`'s own process environment at the moment it's invoked are
passed through to the script phase. Setting `env:` in a CI step makes the
vars available to the *step's* shell but, unless they're exported on the same
line as `xcodebuild` (or `export`ed in the step's shell before the call),
they won't reach the Run Script. Method (3) above is the only form that
reliably works on CI — methods (1) and (2) are convenience patterns for local
Xcode development only.

### CI tolerance

CI runs without `OKTA_*` env vars set. The expected behaviour is:

- `xcodebuild build` exits **0**; the Info.plist contains four
  `__OKTA_NOT_CONFIGURED__` sentinel strings.
- The app launches in the simulator and displays the inline error banner
  "Okta is not configured on this build — see README."
- `xcodebuild test -only-testing:AcmeBankUITests` runs, and the end-to-end
  sign-in test reports `XCTSkip` (not failure) because `OktaConfig.load()`
  returned `.notConfigured`.

A CI run that goes red because env vars are missing — script `exit 1`, app
crash on launch, XCUITest failure asserting on Okta state — is a config
tolerance defect, not a real defect.
