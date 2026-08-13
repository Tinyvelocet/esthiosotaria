import SwiftUI

/// Onboarding step 2b — manual city/ZIP entry (location denied or unavailable).
/// Pure design surface: one text field, one primary action, one back link.
struct OnboardingManualEntryView: View {
    @Binding var text: String
    let errorMessage: String?
    let onSearch: () -> Void
    let onBack: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Text("Where do you shop?")
                .font(.title2.bold())
            TextField("City or ZIP code", text: $text)
                .textFieldStyle(.roundedBorder)
                .frame(maxWidth: 320)
                .onSubmit(onSearch)
            if let errorMessage {
                Text(errorMessage)
                    .foregroundStyle(.red)
                    .font(.callout)
            }
            Button("Find stores near me") { onSearch() }
                .buttonStyle(.borderedProminent)
            Button("Back") { onBack() }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
        }
    }
}

#Preview("Manual entry") {
    OnboardingManualEntryView(
        text: .constant("Palo Alto, CA"),
        errorMessage: nil,
        onSearch: {},
        onBack: {}
    )
    .padding()
}

#Preview("Manual entry — error") {
    OnboardingManualEntryView(
        text: .constant("Xyzzy"),
        errorMessage: "Couldn't find that place. Try a city name or ZIP code.",
        onSearch: {},
        onBack: {}
    )
    .padding()
}
