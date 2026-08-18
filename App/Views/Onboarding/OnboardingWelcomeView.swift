import SwiftUI

/// Onboarding step 1 — welcome. Pure design surface: no state, one action.
///
/// **Design notes:** sets the tone for the app. `RecallMark` — the app's
/// own dot-built seal — replaces a stock SF Symbol so the first thing a
/// user sees is this app's material, not a generic cart icon.
struct OnboardingWelcomeView: View {
    let onStart: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            RecallMark(size: 88)
            Text("Food recalls for your stores")
                .font(Design.BrandFont.display)
                .multilineTextAlignment(.center)
            Text("EsthioSotaria watches FDA and USDA food recalls and flags the ones that could be on the shelves of up to 4 grocery stores near you. Your location never leaves this device.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            Button("Get started") { onStart() }
                .buttonStyle(.appPrimary)
        }
        .frame(maxWidth: 420)
    }
}

#Preview("Welcome") {
    OnboardingWelcomeView(onStart: {})
        .padding()
}

#Preview("Welcome — Dark") {
    OnboardingWelcomeView(onStart: {})
        .padding()
        .preferredColorScheme(.dark)
}
