import XCTest
@testable import AcmeBank

/// Covers `SignedInUser.init(session:)`'s `displayName` splitting
/// strategy. The init has several distinct branches that the
/// type-level doc comment calls out explicitly:
///
///  - single-token name           \u2192 `firstName: name, lastName: ""`
///  - two-token name              \u2192 split on the single space
///  - multi-word last name        \u2192 split only on the FIRST whitespace
///  - whitespace-only displayName \u2192 empty `firstName` / `lastName`
///  - internal double space       \u2192 trailing trim strips the residue
///
/// `UserSession.init(idToken:accessToken:)` already rejects empty
/// `name` claims at the decode boundary, so the whitespace-only
/// branch is defensive-only \u2014 but the dashboard greeting still has
/// to render without crashing if it ever reaches that branch, hence
/// the test.
final class SignedInUserTests: XCTestCase {

    // MARK: - Helpers

    /// Builds a `UserSession` with the given `displayName`. Other
    /// fields are filled with stable fixture values \u2014 only the
    /// `displayName` projection is under test here. The access token
    /// is the empty string so an accidental network call would 401
    /// rather than impersonate a real user (same posture as the
    /// `HomeDashboardUITests` stub).
    private func session(displayName: String,
                         email: String = "fixture@example.com") -> UserSession {
        UserSession(
            userId:        "fixture-sub",
            displayName:   displayName,
            email:         email,
            accessToken:   "",
            authTimestamp: Date(timeIntervalSince1970: 1_700_000_000),
            deviceName:    "Fixture Device"
        )
    }

    // MARK: - Single-token name

    /// A mononym like `"Cher"` has no whitespace to split on. The
    /// greeting layer treats an empty `lastName` as "render only the
    /// first name", which matches the mockup.
    func test_init_session_singleToken_firstNameOnly() {
        let user = SignedInUser(session: session(displayName: "Cher"))
        XCTAssertEqual(user.firstName, "Cher")
        XCTAssertEqual(user.lastName,  "")
    }

    // MARK: - Two-token name

    /// The canonical "first last" shape \u2014 the fixture used by
    /// `HomeDashboardUITests` and the SwiftUI `#Preview`.
    func test_init_session_twoTokens_splitsOnSpace() {
        let user = SignedInUser(session: session(displayName: "Demo Person"))
        XCTAssertEqual(user.firstName, "Demo")
        XCTAssertEqual(user.lastName,  "Person")
    }

    // MARK: - Multi-word last name

    /// Multi-particle surnames ("van der Berg", "de la Cruz") must
    /// survive intact on line 2 \u2014 the split is on the **first**
    /// whitespace run, not every whitespace.
    func test_init_session_multiWordLastName_splitsOnFirstSpaceOnly() {
        let user = SignedInUser(session: session(displayName: "Jane van der Berg"))
        XCTAssertEqual(user.firstName, "Jane")
        XCTAssertEqual(user.lastName,  "van der Berg")
    }

    // MARK: - Whitespace-only displayName

    /// `UserSession.init(idToken:accessToken:)` rejects empty `name`
    /// claims, but the memberwise init used by tests and the UI-test
    /// stub does not, so the projection must handle a
    /// whitespace-only `displayName` without crashing. The dashboard
    /// renders an empty greeting line in this case rather than
    /// trapping.
    func test_init_session_whitespaceOnly_yieldsEmptyFields() {
        let user = SignedInUser(session: session(displayName: "   "))
        XCTAssertEqual(user.firstName, "")
        XCTAssertEqual(user.lastName,  "")
    }

    /// The truly-empty `displayName` branch \u2014 the projection's
    /// `trimmingCharacters(in: .whitespaces)` short-circuits to the
    /// same empty-fields outcome.
    func test_init_session_empty_yieldsEmptyFields() {
        let user = SignedInUser(session: session(displayName: ""))
        XCTAssertEqual(user.firstName, "")
        XCTAssertEqual(user.lastName,  "")
    }

    // MARK: - Internal double space

    /// `"Alice  Bob"` (two spaces between tokens): `firstIndex(where:
    /// isWhitespace)` finds the first space, the substring after it
    /// is `" Bob"`, and the trailing `.trimmingCharacters(in:
    /// .whitespaces)` strips the leading whitespace so the
    /// `lastName` lands as `"Bob"`. This pins that guarantee \u2014 the
    /// PR review specifically flagged this as worth a regression
    /// test.
    func test_init_session_doubleSpaceBetweenTokens_trimsResidue() {
        let user = SignedInUser(session: session(displayName: "Alice  Bob"))
        XCTAssertEqual(user.firstName, "Alice")
        XCTAssertEqual(user.lastName,  "Bob")
    }

    /// Leading whitespace before a single-token name: the outer
    /// `.trimmingCharacters` strips it before splitting, so the
    /// result is the bare token with an empty last name.
    func test_init_session_leadingWhitespace_singleToken_trims() {
        let user = SignedInUser(session: session(displayName: "  Cher"))
        XCTAssertEqual(user.firstName, "Cher")
        XCTAssertEqual(user.lastName,  "")
    }

    /// Trailing whitespace after a two-token name: the trailing
    /// trim on the `after` slice strips it from `lastName`.
    func test_init_session_trailingWhitespace_twoTokens_trims() {
        let user = SignedInUser(session: session(displayName: "Demo Person   "))
        XCTAssertEqual(user.firstName, "Demo")
        XCTAssertEqual(user.lastName,  "Person")
    }

    // MARK: - Email passthrough

    /// `email` is copied straight through from the session \u2014 no
    /// derivation, no fallback. Pinned here so a future refactor
    /// can't silently start synthesising it from `displayName`.
    func test_init_session_emailIsCopiedThrough() {
        let user = SignedInUser(
            session: session(displayName: "Demo Person",
                             email:       "demo.person@example.com")
        )
        XCTAssertEqual(user.email, "demo.person@example.com")
    }
}
