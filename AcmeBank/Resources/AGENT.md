# AcmeBank app module — agent notes

Scope: SwiftUI app target (`AcmeBank/`). For repo-wide context (tech
stack, branch model, Okta build config, keychain rules) read the root
`AGENT.md` / `CLAUDE.md` first; this file only captures **per-module**
conventions that aren't obvious from the root doc.

## Composition root

The signed-in root view is `HomeDashboardView`, not the prior
`LandingView` placeholder. `AcmeBank/App/RootCoordinator.swift` is the
single seam that maps `AuthState` to a root view; `ContentView` calls
`RootCoordinator.view(for: coordinator)` and does nothing else.

When you add a new top-level destination (a sign-up flow, a forced
password reset, a feature gate that needs its own root), extend
`RootCoordinator.Destination` and its `view(for:)` builder — do NOT
add another `switch` in `ContentView`. Two switches drift; one
doesn't.

## Features/

- `Features/Home/` — the dashboard module. Owns its own
  `NavigationStack` (the dashboard's quick-action pushes resolve
  against `HomeDashboardView`'s `.navigationDestination(for:)`), so
  `RootCoordinator` deliberately does NOT wrap it in an outer
  `NavigationStack`. Adding one would break the destination
  resolver's scope.
- `Features/Login/` — the sign-in form.
- `Features/Landing/` — retained for the LandingView tests but no
  longer in the composition root.

## Auth projection

Feature view-models (e.g. `HomeDashboardViewModel`) consume
`SignedInUser`, not `UserSession`. `RootCoordinator` projects the
session at the composition-root boundary so feature code can never
accidentally log the access token or persist a token-bearing value.
If you need a new identity field on a feature screen, add it to
`SignedInUser` (and its `init(session:)` projection) rather than
passing `UserSession` down.

## XCUITest hook

`-uiTestSignedIn` launch arg is honoured by `AcmeBankApp` to pre-seed
`AppCoordinator.state = .signedIn(stubSession)` so
`HomeDashboardUITests` can land on the dashboard without driving the
real Okta flow. Not gated on `#if DEBUG` — XCUITests run against
Release-config builds on CI.
