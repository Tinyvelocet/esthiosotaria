import SwiftUI

/// 🎨 Design Gallery — every major screen on one scrollable canvas, rendered
/// from mock data with zero network access. Use it to compare screens while
/// iterating on visual design.
///
/// Run it: in the app, set `SHOW_DESIGN_GALLERY = true` below (or preview it).
/// Each section embeds the same isolated view structs the real app uses, so
/// design changes propagate 1:1.
struct DesignGalleryView: View {
    /// Flip to true to show the gallery at launch (see EsthiosotariaApp).
    static let showAtLaunch = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 32) {
                galleryHeader("Onboarding — Welcome") {
                    OnboardingWelcomeView(onStart: {})
                        .padding()
                        .background(.quaternary, in: RoundedRectangle(cornerRadius: 12))
                }

                galleryHeader("Onboarding — Location denied") {
                    OnboardingLocatingView(isDenied: true, onManualEntry: {})
                        .padding()
                        .background(.quaternary, in: RoundedRectangle(cornerRadius: 12))
                }

                galleryHeader("Onboarding — Manual entry") {
                    OnboardingManualEntryView(
                        text: .constant("Palo Alto, CA"),
                        errorMessage: nil,
                        onSearch: {},
                        onBack: {}
                    )
                    .padding()
                    .background(.quaternary, in: RoundedRectangle(cornerRadius: 12))
                }

                galleryHeader("Onboarding — Store picker (2 of 4 selected)") {
                    OnboardingStorePickerView(
                        stores: MockData.discoveryStores,
                        selectedStores: [MockData.costco, MockData.piazzas],
                        source: .overpass,
                        isLoading: false,
                        errorMessage: nil,
                        radiusMiles: .constant(15),
                        onRadiusCommit: {},
                        onToggle: { _ in },
                        onDone: {}
                    )
                    .frame(height: 480)
                    .background(.quaternary, in: RoundedRectangle(cornerRadius: 12))
                }

                galleryHeader("Recall list — populated") {
                    RecallListView(viewModel: .designState())
                        .environmentObject(UserSettingsStore.designState())
                        .frame(height: 640)
                }

                galleryHeader("Recall detail — Class I chain match") {
                    NavigationStack {
                        RecallDetailView(item: MockData.items(for: [MockData.kirklandMadeleines], stores: MockData.fourStores)[0])
                    }
                    .environmentObject(UserSettingsStore.designState())
                    .frame(height: 560)
                }

                galleryHeader("Settings — populated") {
                    NavigationStack {
                        SettingsView()
                    }
                    .environmentObject(UserSettingsStore.designState())
                    .frame(height: 640)
                }
            }
            .padding()
        }
        .navigationTitle("Design Gallery")
    }

    private func galleryHeader(_ title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.title3.bold())
            content()
        }
    }
}

#Preview("Design Gallery") {
    NavigationStack {
        DesignGalleryView()
    }
}
