import SwiftUI

/// Onboarding step 2a — locating in progress / permission denied.
/// Pure design surface: shows spinner, or the denied-state escape hatch.
///
/// **Design notes:** the denied branch must stay friendly — no guilt-trip
/// copy. Manual entry is a first-class path, not a punishment.
struct OnboardingLocatingView: View {
    let isDenied: Bool
    let onManualEntry: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            if isDenied {
                Image(systemName: "location.slash")
                    .font(.system(size: 44))
                    .foregroundStyle(.secondary)
                Text("Location access was denied")
                    .font(.title2.bold())
                Text("No problem — type your city instead. Nothing is sent anywhere.")
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                Button("Enter my city manually") { onManualEntry() }
                    .buttonStyle(.borderedProminent)
            } else {
                ProgressView()
                    .controlSize(.large)
                Text("Finding your location…")
                    .font(.headline)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

#Preview("Locating") {
    OnboardingLocatingView(isDenied: false, onManualEntry: {})
        .padding()
}

#Preview("Denied") {
    OnboardingLocatingView(isDenied: true, onManualEntry: {})
        .padding()
}
