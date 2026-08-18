import SwiftUI
#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

extension Color {
    /// A custom color that adapts to light/dark appearance, the same way
    /// system colors do — for palette values with no built-in SwiftUI
    /// equivalent (there's no `Color.cream`).
    static func dynamic(light: Color, dark: Color) -> Color {
        #if os(iOS)
        Color(UIColor { traits in
            traits.userInterfaceStyle == .dark ? UIColor(dark) : UIColor(light)
        })
        #elseif os(macOS)
        Color(NSColor(name: nil) { appearance in
            let isDark = appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
            return NSColor(isDark ? dark : light)
        })
        #endif
    }
}

/// Central design tokens. When iterating on visual design, change values
/// here (or in the screen previews) instead of hunting through views.
///
/// Palette reference: W&Cie's "Monoprix is back" identity work — warm
/// paper base, one saturated red as the sole "pay attention" signal, deep
/// navy carrying everything quiet (chrome, text, the brand tint). Danger
/// is the only thing allowed to turn red; nothing else competes with it.
enum Design {
    /// Warm paper surface — the app's background language, replacing flat
    /// system white/black. Both variants stay warm (near-black, not cold
    /// gray) so dark mode reads as the same paper, just at night.
    enum Paper {
        static let background = Color.dynamic(
            light: Color(red: 0.965, green: 0.945, blue: 0.910),  // #F6F1E8
            dark: Color(red: 0.106, green: 0.094, blue: 0.082))   // #1B1815
        static let surface = Color.dynamic(
            light: Color(red: 0.992, green: 0.984, blue: 0.969),  // #FDFBF7
            dark: Color(red: 0.153, green: 0.137, blue: 0.122))   // #27231F
        static let line = Color.dynamic(
            light: Color(red: 0.106, green: 0.094, blue: 0.082).opacity(0.12),
            dark: Color(red: 0.965, green: 0.945, blue: 0.910).opacity(0.14))
        /// Primary "ink" — replaces `.primary` where the warm paper world
        /// needs a deliberate near-black/near-cream instead of the system default.
        static let ink = Color.dynamic(
            light: Color(red: 0.106, green: 0.094, blue: 0.082),  // #1B1815
            dark: Color(red: 0.965, green: 0.945, blue: 0.910))   // #F6F1E8
    }

    /// Severity palette — colorblind-safe trio (red / orange / gray), used
    /// per-recall where a discrete Class I/II/III label is shown. Unrelated
    /// to `Danger`, which is the continuous aggregate score below.
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
        /// The app's one interactive tint (buttons, links, toggles),
        /// applied once at the root via `.tint(...)`. Deep navy, not red —
        /// red is reserved for danger. Nothing routine should share that hue.
        static let brand = Color.dynamic(
            light: Color(red: 0.086, green: 0.129, blue: 0.235),  // #16213C
            dark: Color(red: 0.478, green: 0.573, blue: 0.784))   // #7A92C8 (lighter navy, readable on dark paper)
    }

    /// Continuous 0...1 aggregate danger scale for the store dashboard —
    /// distinct from `Severity` (which stays discrete/per-recall). Fades
    /// from the paper surface itself up to full signal red, so an empty
    /// store visually recedes and a dangerous one visually dominates.
    enum Danger {
        private static let fullRGB = (r: 0.816, g: 0.063, b: 0.165) // #D0102A
        private static let emptyLightRGB = (r: 0.992, g: 0.984, b: 0.969)
        private static let emptyDarkRGB = (r: 0.153, g: 0.137, b: 0.122)

        static let empty = Color.dynamic(
            light: Color(red: emptyLightRGB.r, green: emptyLightRGB.g, blue: emptyLightRGB.b),
            dark: Color(red: emptyDarkRGB.r, green: emptyDarkRGB.g, blue: emptyDarkRGB.b))
        static let full = Color(red: fullRGB.r, green: fullRGB.g, blue: fullRGB.b)

        /// Interpolates the appearance-correct paper tone → signal red, so
        /// an empty store recedes into *whichever* background is showing
        /// instead of turning into a stray bright patch in dark mode.
        /// `score` is clamped to 0...1.
        static func color(for score: Double) -> Color {
            let t = min(max(score, 0), 1)
            return Color.dynamic(
                light: mix(emptyLightRGB, fullRGB, t),
                dark: mix(emptyDarkRGB, fullRGB, t))
        }

        private static func mix(_ a: (r: Double, g: Double, b: Double), _ b: (r: Double, g: Double, b: Double), _ t: Double) -> Color {
            Color(red: lerp(a.r, b.r, t), green: lerp(a.g, b.g, t), blue: lerp(a.b, b.b, t))
        }

        private static func lerp(_ a: Double, _ b: Double, _ t: Double) -> Double {
            a + (b - a) * t
        }
    }

    enum Spacing {
        static let cardVertical: CGFloat = 14
        /// Gap within a tightly related pair (e.g. title + reason).
        static let cardTightGap: CGFloat = 4
        /// Gap between a card's distinct groups (meta row, content, chips).
        static let cardGroupGap: CGFloat = 10
        static let screenPadding: CGFloat = 24
        static let sectionGap: CGFloat = 12
    }

    enum Radius {
        /// Cards, map clips, inert placeholders — the app's one corner radius.
        static let card: CGFloat = 12
    }

    /// The brand display face — a warm editorial serif (DM Serif Display,
    /// SIL OFL 1.1, bundled at `App/Resources/Fonts`). Reserved for the
    /// app's first-impression headings; body text and UI labels stay on the
    /// system SF font so the brand face reads as a signature, not the default.
    enum BrandFont {
        /// PostScript name of the bundled face (must match `UIAppFonts`).
        static let name = "DMSerifDisplay-Regular"
        /// Standard large lockup for display headlines.
        static let display = Font.custom(name, size: 34)
        /// A brand-facing heading at an explicit size.
        static func sized(_ size: CGFloat) -> Font { Font.custom(name, size: size) }
    }
}
