import SwiftUI

/// Central design tokens. When iterating on visual design, change values
/// here (or in the screen previews) instead of hunting through views.
enum Design {
    /// Severity palette — colorblind-safe trio (red / orange / gray).
    enum Severity {
        static let critical = Color.red
        static let serious = Color.orange
        static let minor = Color.gray
        static let unclassified = Color.secondary
    }

    /// Section accent colors.
    enum Accent {
        static let storeMatch = Color.red
        static let warning = Color.orange
    }

    enum Spacing {
        static let cardVertical: CGFloat = 4
        static let screenPadding: CGFloat = 24
        static let sectionGap: CGFloat = 12
    }
}
