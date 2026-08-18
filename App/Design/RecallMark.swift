import SwiftUI

/// The app's mark — a ring of dots (the same primitive `DangerMark` and
/// `PatternBackground` are built from) standing in for a stamped seal,
/// with a dot-matrix exclamation at its center. Used at first impression
/// instead of a stock SF Symbol, so the app introduces its own visual
/// material before anything else.
struct RecallMark: View {
    var size: CGFloat = 96
    var color: Color = Design.Accent.brand

    private let ringDotCount = 20

    var body: some View {
        ZStack {
            ForEach(0..<ringDotCount, id: \.self) { i in
                let angle = (Double(i) / Double(ringDotCount)) * 2 * .pi
                let radius = size * 0.46
                Circle()
                    .fill(color)
                    .frame(width: size * 0.045, height: size * 0.045)
                    .offset(x: CGFloat(cos(angle)) * radius, y: CGFloat(sin(angle)) * radius)
            }
            DotGlyph(
                pattern: Self.exclamationPattern,
                color: color,
                dotDiameter: size * 0.09,
                spacing: size * 0.05
            )
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }

    static let exclamationPattern: [UInt8] = [0b010, 0b010, 0b010, 0b010, 0b010, 0b000, 0b010]
}

#Preview("Recall mark") {
    HStack(spacing: 24) {
        RecallMark(size: 96)
        RecallMark(size: 56, color: Design.Danger.full)
    }
    .padding()
    .background(Design.Paper.background)
}
