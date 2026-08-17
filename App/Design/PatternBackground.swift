import SwiftUI
import RecallKit

/// Generative background — the same fill-circle primitive as `DangerMark`,
/// scattered at low opacity. Density is driven by real data (how many
/// active recalls touch the user's stores) instead of being purely
/// decorative, so a quiet week looks quiet and a busy one looks busier.
struct PatternBackground: View {
    /// 0...1 — drives how many marks appear, not just their opacity.
    var intensity: Double = 0.2

    private var markCount: Int {
        8 + Int(clamped(intensity) * 24) // 8...32
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                ForEach(0..<markCount, id: \.self) { i in
                    let point = seededPoint(index: i, in: proxy.size)
                    Circle()
                        .fill(Design.Danger.full.opacity(0.04 + point.weight * 0.05))
                        .frame(width: point.size, height: point.size)
                        .position(x: point.x, y: point.y)
                }
            }
        }
        .allowsHitTesting(false)
    }

    private struct SeededPoint {
        let x: CGFloat
        let y: CGFloat
        let size: CGFloat
        let weight: Double
    }

    /// Deterministic per-index placement — a fixed hash, not `Int.random`.
    /// The pattern should hold still across re-renders for a given data
    /// state, not reshuffle every time SwiftUI redraws the view.
    private func seededPoint(index: Int, in canvasSize: CGSize) -> SeededPoint {
        func hash(_ n: Int) -> Double {
            var x = UInt64(bitPattern: Int64(n &* 2_654_435_761 &+ 0x9E37_79B9))
            x ^= x >> 33
            x = x &* 0xff51_afd7_ed55_8ccd
            x ^= x >> 33
            return Double(x % 10_000) / 10_000
        }
        let x = hash(index * 3 + 1) * max(canvasSize.width, 1)
        let y = hash(index * 3 + 2) * max(canvasSize.height, 1)
        let size = 6 + hash(index * 3 + 3) * 22
        return SeededPoint(x: x, y: y, size: size, weight: hash(index * 3))
    }

    private func clamped(_ value: Double) -> Double { min(max(value, 0), 1) }
}

#Preview("Pattern background") {
    ZStack {
        Design.Paper.background
        PatternBackground(intensity: 0.6)
    }
    .frame(width: 400, height: 400)
}
