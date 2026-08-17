import SwiftUI

/// Onboarding step 1 — welcome. Pure design surface: no state, one action.
///
/// **Design notes:** sets the tone for the app. Current treatment: SF Symbol
/// hero, title, privacy reassurance, single CTA.
struct OnboardingWelcomeView: View {
    let onStart: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "cart.fill")
                .font(.system(size: 56))
                .foregroundStyle(Design.Accent.brand)
            Text("Food recalls for your stores")
                .font(.title.bold())
                .multilineTextAlignment(.center)
            Text("EsthioSotaria watches FDA and USDA food recalls and flags the ones that could be on the shelves of up to 4 grocery stores near you. Your location never leaves this device.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            Button("Get started") { onStart() }
                .buttonStyle(.borderedProminent)
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
