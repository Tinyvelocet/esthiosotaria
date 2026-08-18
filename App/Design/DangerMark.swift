import SwiftUI
import RecallKit

/// The app's signature device. Earlier drafts rendered the danger score as
/// a circular progress-ring fill — visually indistinguishable from a
/// battery indicator or a Screen Time ring. This version builds the
/// numeral itself out of the same dot primitive `PatternBackground`
/// scatters ambiently: structure emerging from the same material as the
/// noise, rather than a borrowed gauge shape. Color still carries the
/// at-a-glance severity signal (a cluster of red dots vs. pale ones)
/// before anyone reads the digits.
struct DangerMark: View {
    let score: Double // 0...1
    var size: CGFloat = 64
    var showsLabel: Bool = false

    private var clamped: Double { min(max(score, 0), 1) }

    var body: some View {
        ZStack {
            Circle()
                .fill(Design.Paper.surface)
            Circle()
                .strokeBorder(Design.Paper.line, lineWidth: 1)
            DotNumeral(digits: digits, color: dotColor, dotDiameter: dotDiameter, spacing: dotSpacing)
        }
        .frame(width: size, height: size)
        .animation(.spring(response: 0.5, dampingFraction: 0.8), value: clamped)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(showsLabel ? "Danger score" : "")
        .accessibilityValue(showsLabel ? accessibilityValue : "")
        .accessibilityHidden(!showsLabel)
    }

    /// Digits to render, or `nil` for the empty (score == 0) dash state.
    private var digits: [Int]? {
        clamped == 0 ? nil : String(Int((clamped * 100).rounded())).compactMap(\.wholeNumberValue)
    }

    private var dotColor: Color { Design.Danger.color(for: clamped) }

    private var dotDiameter: CGFloat {
        let count = digits?.count ?? 1
        // Fit N digits (3 dots wide each, 1 gap between) inside ~62% of the circle.
        let totalDotsWide = CGFloat(count) * 3 + CGFloat(max(count - 1, 0))
        return (size * 0.62) / totalDotsWide
    }

    private var dotSpacing: CGFloat { dotDiameter * 0.35 }

    private var accessibilityValue: String {
        clamped == 0 ? "none" : "\(Int((clamped * 100).rounded())) percent"
    }
}

/// Renders a sequence of digits (or a dash when `nil`) as a dot-matrix
/// numeral — each digit a fixed 3×5 grid, digits separated by a gap.
private struct DotNumeral: View {
    let digits: [Int]?
    let color: Color
    let dotDiameter: CGFloat
    let spacing: CGFloat

    var body: some View {
        HStack(spacing: spacing * 2) {
            if let digits {
                ForEach(Array(digits.enumerated()), id: \.offset) { _, digit in
                    DotGlyph(pattern: Self.digitPatterns[digit], color: color, dotDiameter: dotDiameter, spacing: spacing)
                }
            } else {
                DotGlyph(pattern: Self.dashPattern, color: color, dotDiameter: dotDiameter, spacing: spacing)
            }
        }
    }

    /// 3-wide × 5-tall dot grids. Each row is 3 bits, top to bottom.
    static let digitPatterns: [[UInt8]] = [
        [0b111, 0b101, 0b101, 0b101, 0b111], // 0
        [0b010, 0b110, 0b010, 0b010, 0b111], // 1
        [0b111, 0b001, 0b111, 0b100, 0b111], // 2
        [0b111, 0b001, 0b111, 0b001, 0b111], // 3
        [0b101, 0b101, 0b111, 0b001, 0b001], // 4
        [0b111, 0b100, 0b111, 0b001, 0b111], // 5
        [0b111, 0b100, 0b111, 0b101, 0b111], // 6
        [0b111, 0b001, 0b010, 0b010, 0b010], // 7
        [0b111, 0b101, 0b111, 0b101, 0b111], // 8
        [0b111, 0b101, 0b111, 0b001, 0b111], // 9
    ]
    static let dashPattern: [UInt8] = [0b000, 0b000, 0b111, 0b000, 0b000]
}

#Preview("Danger marks") {
    HStack(spacing: 16) {
        DangerMark(score: 0, size: 72, showsLabel: true)
        DangerMark(score: 0.25, size: 72, showsLabel: true)
        DangerMark(score: 0.5, size: 72, showsLabel: true)
        DangerMark(score: 0.71, size: 72, showsLabel: true)
        DangerMark(score: 1.0, size: 72, showsLabel: true)
    }
    .padding()
    .background(Design.Paper.background)
}

#Preview("Danger marks — large") {
    HStack(spacing: 24) {
        DangerMark(score: 0.55, size: 140, showsLabel: true)
        DangerMark(score: 1.0, size: 140, showsLabel: true)
    }
    .padding()
    .background(Design.Paper.background)
}
