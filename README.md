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
- **Auth:** Okta OIDC (`okta-mobile-swift`, pinned to the 2.x minor line)
- **Networking:** `URLSession` + async/await
- **Tests:** XCTest (unit) + XCUITest (critical flows)

## Scope of this PR (MD066)

This PR delivers the **infrastructure / configuration layer** for Okta
DirectAuth only:

- The `okta-mobile-swift` SPM dependency, pinned to the 2.x minor line.
- The `AcmeBankUITests` target definition + scheme wiring (an empty target —
  no XCUITest sources yet).
- The `Inject Okta Config` pre-build script that writes the four `OKTA_*`
  env vars into `AcmeBank/Info.plist`, or writes the `__OKTA_NOT_CONFIGURED__`
  sentinel when they are unset.
- The committed `AcmeBank/Info.plist.example` template and the `.gitignore`
  entry that keeps the working `AcmeBank/Info.plist` out of version control.
- The developer documentation below.

The runtime pieces — `OktaConfig.swift`, `AuthService.swift`, the login
feature, the "Okta is not configured on this build" banner, and the
`XCTSkipUnless`-guarded XCUITest — are **deferred to follow-on PRs**. Until
those land, the behaviour described in the [CI tolerance](#ci-tolerance)
section is **forward-looking** (what the build will do once the runtime
pieces are wired up), not present-tense.

## Okta build configuration

Okta tenant values are **not** committed to the repo. They are injected into
`AcmeBank/Info.plist` at build time by the `Inject Okta Config` pre-build
script on the `AcmeBank` target, reading from environment variables on the
build machine. Xcode then copies + variable-expands that file into the built
app bundle, so the keys reach `Bundle.main.infoDictionary` at runtime.

> ⚠️ **Security: `AcmeBank/Info.plist` is `.gitignore`d on purpose — do not
> remove that entry.** The pre-build script overwrites this file on every
> build, so when you build locally with the four `OKTA_*` env vars set, real
> tenant values (client ID, issuer) end up on disk inside the working tree.
> A stray `git add -A` or an IDE auto-stage would otherwise leak them into a
> commit. The committed template `AcmeBank/Info.plist.example` contains only
> sentinel placeholders and is what the pre-build script seeds the working
> plist from on a fresh clone.
>
> A future PR will add a CI lint step that fails the build if a tracked
> `*.plist` ever contains a non-sentinel `OktaIssuer` / `OktaClientId`
> value, as a belt-and-braces safeguard. Until that lands, treat the
> `.gitignore` entry + the `.example` template as the only line of defence
> and review your staged diff before pushing.

### Required environment variables

| Variable             | Example                                          |
|----------------------|--------------------------------------------------|
| `OKTA_ISSUER`        | `https://dev-123456.okta.com/oauth2/default`     |
| `OKTA_CLIENT_ID`     | `0oabcdefghIJKLMNOPqr`                           |
| `OKTA_REDIRECT_URI`  | `com.acmebank.mobile:/callback`                  |
| `OKTA_SCOPES`        | `openid profile email offline_access`            |

When all four are set, the runtime `OktaConfig.load()` (delivered in a
follow-on PR) will return `.configured(...)` and DirectAuth will run against
your real Okta tenant. When **any** is unset, the pre-build script writes
the sentinel string `__OKTA_NOT_CONFIGURED__` into the Info.plist for that
key (it **never** fails the build); once the runtime layer lands,
`OktaConfig` will return `.notConfigured(reason)` and the app will launch
showing the "Okta is not configured on this build" banner, and the XCUITest
covering the sign-in flow will be skipped via `XCTSkipUnless`.

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

> **Forward-looking:** the bullets below describe the *target* behaviour
> once the runtime layer (`OktaConfig` + the "not configured" banner +
> the `XCTSkipUnless`-guarded XCUITest) lands in a follow-on PR. In
> *this* PR only the build-script half exists — the `xcodebuild build`
> exit-0 + sentinel-in-plist behaviour is real today; the runtime banner
> and the `XCTSkip` are not yet implemented.

CI runs without `OKTA_*` env vars set. The expected behaviour is:

- `xcodebuild build` exits **0**; `AcmeBank/Info.plist` contains four
  `__OKTA_NOT_CONFIGURED__` sentinel strings. ✅ implemented in this PR.
- The app will launch in the simulator and display the inline error banner
  "Okta is not configured on this build — see README." ⏳ deferred to a
  follow-on PR (requires `OktaConfig.swift` + banner view).
- `xcodebuild test -only-testing:AcmeBankUITests` will run, and the
  end-to-end sign-in test will report `XCTSkip` (not failure) because
  `OktaConfig.load()` returned `.notConfigured`. ⏳ deferred to a follow-on
  PR (requires `OktaConfig.swift` + the XCUITest source itself —
  `AcmeBankUITests/` is currently an empty target).

A CI run that goes red because env vars are missing — script `exit 1`, app
crash on launch, XCUITest failure asserting on Okta state — is a config
tolerance defect, not a real defect.
