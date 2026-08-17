import SwiftUI
import RecallKit

/// A geometric fill mark — the app's one recurring signature device,
/// echoing the reference identity's numerals built from filled circles
/// rather than typeset digits. Drawn at three scales across the app:
/// large on dashboard tiles, small on list rows, tiny across the
/// background pattern. Fill height is literally the danger score, so
/// "how full is this circle" reads before any label does.
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
                .fill(Design.Danger.color(for: clamped))
                .mask(fillMask)
            Circle()
                .strokeBorder(Design.Paper.line, lineWidth: 1)
            if showsLabel {
                Text(percentLabel)
                    .font(.system(size: size * 0.24, weight: .bold, design: .rounded))
                    .foregroundStyle(clamped > 0.5 ? .white : Design.Paper.ink)
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(!showsLabel)
    }

    private var fillMask: some View {
        GeometryReader { proxy in
            VStack(spacing: 0) {
                Spacer(minLength: 0)
                Rectangle().frame(height: proxy.size.height * clamped)
            }
        }
    }

    private var percentLabel: String {
        clamped == 0 ? "—" : "\(Int((clamped * 100).rounded()))"
    }
}

#Preview("Danger marks") {
    HStack(spacing: 16) {
        DangerMark(score: 0, size: 64, showsLabel: true)
        DangerMark(score: 0.25, size: 64, showsLabel: true)
        DangerMark(score: 0.5, size: 64, showsLabel: true)
        DangerMark(score: 0.75, size: 64, showsLabel: true)
        DangerMark(score: 1.0, size: 64, showsLabel: true)
    }
    .padding()
    .background(Design.Paper.background)
}
