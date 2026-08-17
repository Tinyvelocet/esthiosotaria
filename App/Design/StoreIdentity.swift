import SwiftUI
import RecallKit

/// Derives a stable visual identity (color + monogram) for a store from its
/// name, so the same physical store always renders the same badge no
/// matter which discovery call or screen produced the `Store` value.
///
/// Reused everywhere a store is referenced — recall card chips, map
/// markers, the onboarding picker, the detail header — so a store looks
/// like the same thing across the whole app instead of every screen
/// inventing its own treatment.
enum StoreIdentity {

    /// A small, deliberately restrained palette — distinct from the
    /// severity trio (red/orange/gray) and the store-match escalation
    /// red, so a badge is never mistaken for a severity or match signal.
    private static let palette: [Color] = [
        .indigo, .teal, .purple, .brown, .mint, .cyan, .pink, .yellow
    ]

    /// Deterministic, not random or `hashValue`-based: `String.hashValue`
    /// is reseeded per process, so the same store would get a different
    /// color on every launch. A plain scalar sum is stable forever.
    static func color(for store: Store) -> Color {
        let sum = store.name.lowercased().unicodeScalars.reduce(0) { $0 + Int($1.value) }
        return palette[sum % palette.count]
    }

    /// Up to two letters from the store's first two significant words —
    /// "Trader Joe's (Palo Alto)" reads as "TJ", "Whole Foods Market" as "WF".
    static func monogram(for store: Store) -> String {
        let letters = store.name
            .split(separator: " ")
            .compactMap { $0.first(where: \.isLetter) }
            .prefix(2)
        return String(letters).uppercased()
    }
}

/// A small circular identity badge for a store — color + monogram.
struct StoreBadge: View {
    let store: Store
    var size: CGFloat = 20
    /// Draws a store-match-colored ring around the badge. Opt-in and used
    /// only where a separate "selected" state exists alongside identity
    /// (the map) — everywhere else the badge is identity-only, so it never
    /// competes with a screen's own selection affordance (e.g. the
    /// picker's checkmark).
    var isEmphasized: Bool = false

    var body: some View {
        Circle()
            .fill(StoreIdentity.color(for: store))
            .frame(width: size, height: size)
            .overlay {
                Text(StoreIdentity.monogram(for: store))
                    .font(.system(size: size * 0.42, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
            }
            .overlay {
                if isEmphasized {
                    Circle().strokeBorder(Design.Accent.storeMatch, lineWidth: 2)
                        .padding(-2)
                }
            }
            .accessibilityHidden(true) // decorative: the store name label carries the meaning
    }
}

#Preview("Store badges") {
    HStack(spacing: 12) {
        StoreBadge(store: MockData.costco)
        StoreBadge(store: MockData.wholeFoods)
        StoreBadge(store: MockData.piazzas)
        StoreBadge(store: MockData.traderJoes, isEmphasized: true)
    }
    .padding()
}
