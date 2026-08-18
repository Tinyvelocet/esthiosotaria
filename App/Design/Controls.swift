import SwiftUI

/// Filled primary action — navy fill, cream label, the app's own radius
/// and press feedback instead of the system capsule/pill default every
/// `.borderedProminent` button in the app used to render as.
struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.body.weight(.semibold))
            .foregroundStyle(Design.Paper.background)
            .padding(.vertical, 14)
            .padding(.horizontal, 24)
            .background(Design.Accent.brand, in: RoundedRectangle(cornerRadius: Design.Radius.card))
            .opacity(configuration.isPressed ? 0.85 : 1)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
    }
}

/// Outlined secondary action — same radius and brand color as
/// `PrimaryButtonStyle` so the two read as one family, not two different
/// systems glued together.
struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.body.weight(.semibold))
            .foregroundStyle(Design.Accent.brand)
            .padding(.vertical, 10)
            .padding(.horizontal, 16)
            .background(
                RoundedRectangle(cornerRadius: Design.Radius.card)
                    .strokeBorder(Design.Accent.brand, lineWidth: 1.5)
            )
            .opacity(configuration.isPressed ? 0.6 : 1)
    }
}

extension ButtonStyle where Self == PrimaryButtonStyle {
    static var appPrimary: PrimaryButtonStyle { PrimaryButtonStyle() }
}

extension ButtonStyle where Self == SecondaryButtonStyle {
    static var appSecondary: SecondaryButtonStyle { SecondaryButtonStyle() }
}

#Preview("Button styles") {
    VStack(spacing: 16) {
        Button("Get started") {}
            .buttonStyle(.appPrimary)
        Button("Search") {}
            .buttonStyle(.appSecondary)
    }
    .padding()
    .background(Design.Paper.background)
}
