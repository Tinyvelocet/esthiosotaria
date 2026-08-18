import SwiftUI

/// Renders a bitmask grid as a cluster of filled/faint dots — the shared
/// primitive behind `DangerMark`'s numerals, `PatternBackground`'s ambient
/// scatter, and any other mark built from the same material. Each row is
/// read as the low `columns` bits of a `UInt8`, most-significant bit first.
struct DotGlyph: View {
    let pattern: [UInt8]
    let columns: Int
    let color: Color
    let dotDiameter: CGFloat
    let spacing: CGFloat

    init(pattern: [UInt8], columns: Int = 3, color: Color, dotDiameter: CGFloat, spacing: CGFloat) {
        self.pattern = pattern
        self.columns = columns
        self.color = color
        self.dotDiameter = dotDiameter
        self.spacing = spacing
    }

    var body: some View {
        VStack(spacing: spacing) {
            ForEach(0..<pattern.count, id: \.self) { row in
                HStack(spacing: spacing) {
                    ForEach(0..<columns, id: \.self) { col in
                        let on = (pattern[row] >> (columns - 1 - col)) & 1 == 1
                        Circle()
                            .fill(on ? color : color.opacity(0.12))
                            .frame(width: dotDiameter, height: dotDiameter)
                    }
                }
            }
        }
    }
}
