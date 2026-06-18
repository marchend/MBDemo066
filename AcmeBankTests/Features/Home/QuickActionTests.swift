import XCTest
@testable import AcmeBank

/// Pins the canonical four-action sequence the dashboard's Quick
/// Actions row renders.
///
/// The view layer reads `QuickAction.dashboardDefaults` directly, so
/// asserting on the array here is enough to catch a reorder, a
/// rename, or a paste-mistake into the wrong SF Symbol — none of
/// which would surface in `HomeDashboardViewModelTests` (the
/// ViewModel doesn't touch quick actions) and none of which a unit
/// test on the view itself can catch without a UI-host.
///
/// The PR-4 XCUITest exercises the row end-to-end on a running
/// simulator; this test pins the data contract so the XCUITest's
/// `staticTexts["Transfer"]` and friends keep matching the rendered
/// labels even if a refactor moves the data through new types.
final class QuickActionTests: XCTestCase {

    // MARK: - Sequence

    func test_dashboardDefaults_hasExactlyFourActions() {
        XCTAssertEqual(QuickAction.dashboardDefaults.count, 4)
    }

    func test_dashboardDefaults_areInExpectedOrder() {
        let titles = QuickAction.dashboardDefaults.map(\.title)
        XCTAssertEqual(
            titles,
            ["Transfer", "Pay Bills", "Deposit", "More"],
            "The dashboard mockup pins this order — reordering visibly reorders the UI."
        )
    }

    func test_dashboardDefaults_destinationsMatchTitles() {
        let destinations = QuickAction.dashboardDefaults.map(\.destination)
        XCTAssertEqual(
            destinations,
            [.transfer, .payBills, .deposit, .more]
        )
    }

    // MARK: - SF Symbols

    func test_dashboardDefaults_useExpectedSFSymbols() {
        let symbols = QuickAction.dashboardDefaults.map(\.systemImage)
        XCTAssertEqual(
            symbols,
            [
                "arrow.left.arrow.right",
                "doc.text",
                "arrow.down.to.line",
                "ellipsis.circle",
            ],
            "Symbol names are part of the mockup contract — a silent rename here will ship the wrong glyph."
        )
    }

    func test_eachDashboardDefault_hasNonEmptyTitleAndSymbol() {
        for action in QuickAction.dashboardDefaults {
            XCTAssertFalse(
                action.title.isEmpty,
                "title must be non-empty (used as the accessibility label) — got empty for \(action.destination)"
            )
            XCTAssertFalse(
                action.systemImage.isEmpty,
                "systemImage must be non-empty — got empty for \(action.destination)"
            )
        }
    }

    // MARK: - More is the only no-op

    func test_more_isTheOnlyNoOpDestination() {
        let nonMoreDestinations = QuickAction.dashboardDefaults
            .filter { $0.destination != .more }
            .map(\.destination)
        XCTAssertEqual(
            Set(nonMoreDestinations),
            [.transfer, .payBills, .deposit],
            "Exactly one .more entry; the other three push the placeholder destination."
        )
    }

    // MARK: - Identifiable

    func test_id_isDestinationRawValue() {
        // Identifiable id is the destination's raw string so SwiftUI
        // ForEach diffing is stable across renders.
        for action in QuickAction.dashboardDefaults {
            XCTAssertEqual(action.id, action.destination.rawValue)
        }
    }
}
