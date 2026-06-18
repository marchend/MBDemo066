import Foundation

/// A single button in the dashboard's Quick Actions row.
///
/// Pure value type — no SwiftUI, no navigation. The view layer
/// (`QuickActionsRow`) consumes a static `[QuickAction]` and renders
/// each one as a button; tests assert on the static array directly so
/// the "four actions, in this order, with these symbols" contract is
/// pinned without spinning up a view hierarchy.
///
/// ## `DestinationTag`
/// The dashboard mockup wires three of the four actions to a generic
/// "Placeholder Destination" screen (shipped in PR 4) and leaves the
/// fourth ("More") as a no-op. Rather than coupling this value type to
/// a SwiftUI `View` (which would force the test target to import the
/// view module for an enum compare), we tag the destination with a
/// small enum and let the view layer translate the tag into a
/// `NavigationLink` at render time.
public struct QuickAction: Equatable, Hashable, Identifiable {

    /// What the view should do when the button is tapped.
    public enum DestinationTag: String, Equatable, Hashable {
        /// Push the placeholder destination screen (PR 4).
        case transfer
        /// Push the placeholder destination screen (PR 4).
        case payBills
        /// Push the placeholder destination screen (PR 4).
        case deposit
        /// No-op. The mockup leaves "More" inert until a future PR.
        case more
    }

    /// Used as the `Identifiable` id and the persisted/serialised
    /// shape — the destination tag's raw string is stable enough to
    /// double as the row identity.
    public var id: String { destination.rawValue }

    /// Button label shown beneath the symbol (e.g. "Transfer").
    public let title: String

    /// SF Symbol name (e.g. "arrow.left.arrow.right"). Pinned by the
    /// unit test so a silent symbol rename (or a paste-mistake into
    /// the wrong glyph) can't ship.
    public let systemImage: String

    /// What the view should do on tap. See `DestinationTag`.
    public let destination: DestinationTag

    public init(title: String, systemImage: String, destination: DestinationTag) {
        self.title       = title
        self.systemImage = systemImage
        self.destination = destination
    }

    /// The canonical four-action sequence the dashboard renders, in
    /// display order (Transfer / Pay Bills / Deposit / More).
    ///
    /// Pinned `public static` because both the view layer and the
    /// unit test read from this single source of truth — reordering
    /// or renaming an entry here is exactly the change the test is
    /// designed to catch.
    public static let dashboardDefaults: [QuickAction] = [
        QuickAction(
            title:       "Transfer",
            systemImage: "arrow.left.arrow.right",
            destination: .transfer
        ),
        QuickAction(
            title:       "Pay Bills",
            systemImage: "doc.text",
            destination: .payBills
        ),
        QuickAction(
            title:       "Deposit",
            systemImage: "arrow.down.to.line",
            destination: .deposit
        ),
        QuickAction(
            title:       "More",
            systemImage: "ellipsis.circle",
            destination: .more
        ),
    ]
}
